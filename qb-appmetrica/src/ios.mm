#if defined(DM_PLATFORM_IOS)

#import <Foundation/Foundation.h>
#import <AppMetricaCore/AppMetricaCore.h>
#import <AppMetricaCrashes/AppMetricaCrashes.h>
#include <dmsdk/sdk.h>
#include "bridge.h"
#include "commerce_ios.h"

namespace appmetrica {

static dispatch_queue_t worker;
static dispatch_semaphore_t capacity;
static NSString* activeKey;
static NSMutableSet<NSString*>* activeReporters;
static const long kQueueCapacity = 256;

/// Возвращает UTF-8 с сохранением нулевых байтов в строке.
static std::string Utf8(NSData* data) {
    if (data.length == 0) {
        return {};
    }
    return std::string(static_cast<const char*>(data.bytes), data.length);
}

/// Публикует ошибку без обращения к игровому потоку.
static void Fail(uint64_t requestId, const char* code, NSString* message) {
    Complete(requestId, code, Utf8([message dataUsingEncoding:NSUTF8StringEncoding]));
}

/// Логирует ошибки SDK, возникающие после вызова метода отчётности.
static void LogFailure(NSError* error) {
    dmLogWarning("AppMetrica: iOS SDK report failure (%ld)", static_cast<long>(error.code));
}

/// Активирует SDK. Повторный вызов с тем же ключом возвращает успех.
static void Activate(uint64_t requestId, NSDictionary* args) {
    NSString* key = args[@"api_key"];
    if (activeKey) {
        if ([activeKey isEqualToString:key]) {
            Complete(requestId, "", "true");
        } else {
            Fail(requestId, "already_activated", @"SDK уже активирован с другим ключом");
        }
        return;
    }
    if (AMAAppMetrica.activated) {
        Fail(requestId, "already_activated", @"SDK уже активирован другим расширением");
        return;
    }
    AMAAppMetricaConfiguration* config = [[AMAAppMetricaConfiguration alloc] initWithAPIKey:key];
    if (!config) {
        Fail(requestId, "invalid_argument", @"SDK отклонил ключ приложения");
        return;
    }
    if (args[@"data_sending_enabled"]) config.dataSendingEnabled = [args[@"data_sending_enabled"] boolValue];
    if (args[@"location_tracking"]) config.locationTracking = [args[@"location_tracking"] boolValue];
    if (args[@"app_open_tracking"]) config.appOpenTrackingEnabled = [args[@"app_open_tracking"] boolValue];
    if (args[@"automatic_sessions"]) config.sessionsAutoTracking = [args[@"automatic_sessions"] boolValue];
    config.handleActivationAsSessionStart = config.sessionsAutoTracking;
    if (args[@"session_timeout"]) config.sessionTimeout = [args[@"session_timeout"] unsignedIntegerValue];
    if (args[@"logs_enabled"]) config.logsEnabled = [args[@"logs_enabled"] boolValue];
    config.appVersion = args[@"app_version"];
    config.userProfileID = args[@"user_profile_id"];
    if (args[@"crash_reporting"]) {
        AMAAppMetricaCrashesConfiguration* crashes = [[AMAAppMetricaCrashesConfiguration alloc] init];
        crashes.autoCrashTracking = [args[@"crash_reporting"] boolValue];
        [[AMAAppMetricaCrashes crashes] setConfiguration:crashes];
    }
    [AMAAppMetrica activateWithConfiguration:config];
    if (!AMAAppMetrica.activated) {
        Fail(requestId, "activation_failed", @"SDK не подтвердил активацию AppMetrica");
        return;
    }
    activeKey = [key copy];
    activeReporters = [NSMutableSet set];
    Complete(requestId, "", "true");
}

/// Применяет настройки дополнительного SDK-репортёра до первого его использования.
static void ActivateReporter(uint64_t requestId, NSString* key, NSDictionary* args) {
    if ([activeReporters containsObject:key]) {
        Fail(requestId, "already_activated", @"Репортёр уже используется");
        return;
    }
    AMAMutableReporterConfiguration* config = [[AMAMutableReporterConfiguration alloc] initWithAPIKey:key];
    if (!config) {
        Fail(requestId, "invalid_argument", @"SDK отклонил ключ репортёра");
        return;
    }
    if (args[@"data_sending_enabled"]) config.dataSendingEnabled = [args[@"data_sending_enabled"] boolValue];
    if (args[@"session_timeout"]) config.sessionTimeout = [args[@"session_timeout"] unsignedIntegerValue];
    if (args[@"logs_enabled"]) config.logsEnabled = [args[@"logs_enabled"] boolValue];
    config.userProfileID = args[@"user_profile_id"];
    [AMAAppMetrica activateReporterWithConfiguration:config];
    [activeReporters addObject:key];
    Complete(requestId, "", "true");
}

/// Запрашивает выбранные идентификаторы и переводит ключи ответа в формат Lua.
static void Startup(uint64_t requestId, NSArray<NSString*>* keys) {
    NSDictionary<NSString*, AMAStartupKey>* names = @{
        @"device_id": kAMADeviceIDKey,
        @"device_id_hash": kAMADeviceIDHashKey,
        @"uuid": kAMAUUIDKey
    };
    NSMutableArray<AMAStartupKey>* requested = [NSMutableArray arrayWithCapacity:keys.count];
    for (NSString* key in keys) {
        [requested addObject:names[key]];
    }
    dispatch_queue_t callbackQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    [AMAAppMetrica requestStartupIdentifiersWithKeys:requested completionQueue:callbackQueue
        completionBlock:^(NSDictionary<AMAStartupKey, id>* identifiers, NSError* error) {
            if (error || !identifiers) {
                Fail(requestId, "sdk_error", error ? error.localizedDescription : @"SDK не вернул идентификаторы");
                return;
            }
            NSMutableDictionary* result = [NSMutableDictionary dictionaryWithCapacity:keys.count];
            for (NSString* key in keys) {
                id value = identifiers[names[key]];
                if ([value isKindOfClass:[NSString class]]) {
                    result[key] = value;
                }
            }
            NSData* payload = [NSJSONSerialization dataWithJSONObject:result options:0 error:nullptr];
            if (payload) {
                Complete(requestId, "", Utf8(payload));
            } else {
                Fail(requestId, "sdk_error", @"Не удалось сформировать ответ SDK");
            }
        }];
}

/// Создаёт десятичную сумму в независимом от локали формате.
static NSDecimalNumber* Amount(NSDictionary* args) {
    return [NSDecimalNumber decimalNumberWithString:args[@"amount"]
                                             locale:@{NSLocaleDecimalSeparator: @"."}];
}

/// Формирует отчёт о покупке на основе суммы, валюты и данных товара.
static AMARevenueInfo* Revenue(NSDictionary* args) {
    AMAMutableRevenueInfo* info = [[AMAMutableRevenueInfo alloc] initWithPriceDecimal:Amount(args)
                                                                           currency:args[@"currency"]];
    if (args[@"quantity"]) info.quantity = [args[@"quantity"] unsignedIntegerValue];
    info.productID = args[@"product_id"];
    info.payload = args[@"payload"];
    NSDictionary* receipt = args[@"ios_receipt"];
    if (receipt) {
        NSData* data = [[NSData alloc] initWithBase64EncodedString:receipt[@"data_base64"] options:0];
        if (!data.length) return nil;
        info.receiptData = data;
        info.transactionID = receipt[@"transaction_id"];
    }
    return info;
}

/// Формирует отчёт о доходе от рекламы с необязательными строковыми полями.
static AMAAdRevenueInfo* AdRevenue(NSDictionary* args) {
    AMAMutableAdRevenueInfo* info = [[AMAMutableAdRevenueInfo alloc] initWithAdRevenue:Amount(args)
                                                                            currency:args[@"currency"]];
    info.adNetwork = args[@"ad_network"];
    static NSDictionary<NSString*, NSNumber*>* const types = @{
        @"NATIVE": @(AMAAdTypeNative), @"BANNER": @(AMAAdTypeBanner), @"REWARDED": @(AMAAdTypeRewarded),
        @"INTERSTITIAL": @(AMAAdTypeInterstitial), @"OTHER": @(AMAAdTypeOther)
    };
    if (args[@"ad_type"]) info.adType = static_cast<AMAAdType>([types[args[@"ad_type"]] unsignedIntegerValue]);
    info.adUnitID = args[@"ad_unit_id"];
    info.adUnitName = args[@"ad_unit_name"];
    info.adPlacementID = args[@"ad_placement_id"];
    info.adPlacementName = args[@"ad_placement_name"];
    info.precision = args[@"precision"];
    info.payload = args[@"payload"];
    return info;
}

/// Преобразует обновления типизированных атрибутов Lua в профиль iOS SDK.
static AMAUserProfile* Profile(NSArray<NSDictionary*>* attributes) {
    NSMutableArray<AMAUserProfileUpdate*>* updates = [NSMutableArray arrayWithCapacity:attributes.count];
    for (NSDictionary* attribute in attributes) {
        NSString* type = attribute[@"type"];
        NSString* name = attribute[@"name"];
        BOOL reset = [attribute[@"operation"] isEqualToString:@"reset"];
        if ([type isEqualToString:@"string"]) {
            id<AMACustomStringAttribute> item = [AMAProfileAttribute customString:name];
            [updates addObject:reset ? [item withValueReset] : [item withValue:attribute[@"value"]]];
        } else if ([type isEqualToString:@"number"]) {
            id<AMACustomNumberAttribute> item = [AMAProfileAttribute customNumber:name];
            [updates addObject:reset ? [item withValueReset] : [item withValue:[attribute[@"value"] doubleValue]]];
        } else if ([type isEqualToString:@"boolean"]) {
            id<AMACustomBoolAttribute> item = [AMAProfileAttribute customBool:name];
            [updates addObject:reset ? [item withValueReset] : [item withValue:[attribute[@"value"] boolValue]]];
        } else if ([type isEqualToString:@"counter"]) {
            id<AMACustomCounterAttribute> item = [AMAProfileAttribute customCounter:name];
            [updates addObject:[item withDelta:[attribute[@"value"] doubleValue]]];
        }
    }
    return [[AMAUserProfile alloc] initWithUpdates:updates];
}

/// Выполняет одну команду в очереди iOS или регистрирует штатный запрос SDK.
static void Execute(uint64_t requestId, NSString* operation, NSDictionary* args) {
    if ([operation isEqualToString:@"activate"]) {
        Activate(requestId, args);
        return;
    }
    if (!activeKey || !AMAAppMetrica.activated) {
        Fail(requestId, "activation_failed", @"Предыдущая активация AppMetrica не завершилась успешно");
        return;
    }
    if ([operation isEqualToString:@"startup"]) {
        Startup(requestId, args[@"keys"]);
        return;
    }

    NSString* reporterKey = args[@"reporter_key"];
    if ([activeKey isEqualToString:reporterKey]) {
        Fail(requestId, "invalid_argument", @"Ключ репортёра должен отличаться от основного");
        return;
    }
    if ([operation isEqualToString:@"activate_reporter"]) {
        ActivateReporter(requestId, reporterKey, args);
        return;
    }
    id<AMAAppMetricaReporting> reporter = reporterKey ? [AMAAppMetrica reporterForAPIKey:reporterKey] : nil;
    if (reporterKey && !reporter) {
        Fail(requestId, "sdk_error", @"SDK не создал дополнительный репортёр");
        return;
    }
    if (reporter) [activeReporters addObject:reporterKey];

    void (^onFailure)(NSError*) = ^(NSError* error) { LogFailure(error); };
    if ([operation isEqualToString:@"event"]) {
        if (reporter) [reporter reportEvent:args[@"name"] parameters:args[@"params"] onFailure:onFailure];
        else [AMAAppMetrica reportEvent:args[@"name"] parameters:args[@"params"] onFailure:onFailure];
    } else if ([operation isEqualToString:@"profile_id"]) {
        if (reporter) reporter.userProfileID = args[@"value"];
        else AMAAppMetrica.userProfileID = args[@"value"];
    } else if ([operation isEqualToString:@"error"]) {
        NSError* error = [NSError errorWithDomain:args[@"identifier"] code:1
                                        userInfo:@{NSLocalizedDescriptionKey: args[@"message"]}];
        [[AMAAppMetricaCrashes crashes] reportNSError:error onFailure:onFailure];
    } else if ([operation isEqualToString:@"profile"]) {
        AMAUserProfile* profile = Profile(args[@"attributes"]);
        if (reporter) [reporter reportUserProfile:profile onFailure:onFailure];
        else [AMAAppMetrica reportUserProfile:profile onFailure:onFailure];
    } else if ([operation isEqualToString:@"ecommerce"]) {
        AMAECommerce* event = CommerceEvent(args[@"event"]);
        if (!event) {
            Fail(requestId, "invalid_argument", @"Некорректное событие электронной коммерции");
            return;
        }
        if (reporter) [reporter reportECommerce:event onFailure:onFailure];
        else [AMAAppMetrica reportECommerce:event onFailure:onFailure];
    } else if ([operation isEqualToString:@"revenue"]) {
        AMARevenueInfo* revenue = Revenue(args);
        if (!revenue) {
            Fail(requestId, "invalid_argument", @"Некорректные данные покупки");
            return;
        }
        if (reporter) [reporter reportRevenue:revenue onFailure:onFailure];
        else [AMAAppMetrica reportRevenue:revenue onFailure:onFailure];
    } else if ([operation isEqualToString:@"ad_revenue"]) {
        AMAAdRevenueInfo* revenue = AdRevenue(args);
        if (reporter) [reporter reportAdRevenue:revenue onFailure:onFailure];
        else [AMAAppMetrica reportAdRevenue:revenue onFailure:onFailure];
    } else if ([operation isEqualToString:@"send_events"]) {
        if (reporter) [reporter sendEventsBuffer];
        else [AMAAppMetrica sendEventsBuffer];
    } else if ([operation isEqualToString:@"data_sending"]) {
        if (reporter) [reporter setDataSendingEnabled:[args[@"value"] boolValue]];
        else [AMAAppMetrica setDataSendingEnabled:[args[@"value"] boolValue]];
    } else if ([operation isEqualToString:@"location_tracking"]) {
        AMAAppMetrica.locationTrackingEnabled = [args[@"value"] boolValue];
    } else if ([operation isEqualToString:@"set_environment"]) {
        [AMAAppMetrica setAppEnvironmentValue:args[@"value"] forKey:args[@"key"]];
    } else if ([operation isEqualToString:@"clear_environment"]) {
        [AMAAppMetrica clearAppEnvironment];
    } else if ([operation isEqualToString:@"app_open"]) {
        NSURL* url = [NSURL URLWithString:args[@"url"]];
        if (!url || !url.scheme) {
            Fail(requestId, "invalid_argument", @"Некорректный URL");
            return;
        }
        [AMAAppMetrica trackOpeningURL:url];
    } else if ([operation isEqualToString:@"resume"]) {
        if (reporter) [reporter resumeSession];
        else [AMAAppMetrica resumeSession];
    } else if ([operation isEqualToString:@"pause"]) {
        if (reporter) [reporter pauseSession];
        else [AMAAppMetrica pauseSession];
    } else {
        Fail(requestId, "unsupported_feature", @"Команда недоступна");
        return;
    }
    Complete(requestId, "", "true");
}

/// Создаёт ограниченную последовательную очередь уровня процесса.
bool InitializePlatform() {
    if (!worker) {
        worker = dispatch_queue_create("com.defold.appmetrica", DISPATCH_QUEUE_SERIAL);
        capacity = dispatch_semaphore_create(kQueueCapacity);
    }
    return worker && capacity;
}

/// Добавляет работу в очередь без ожидания свободного места или ответа SDK.
bool Submit(uint64_t requestId, const char* operation, const char* json, size_t size) {
    if (dispatch_semaphore_wait(capacity, DISPATCH_TIME_NOW) != 0) {
        return false;
    }
    NSString* name = [NSString stringWithUTF8String:operation];
    NSData* data = [NSData dataWithBytes:json length:size];
    dispatch_async(worker, ^{
        @autoreleasepool {
            @try {
                NSDictionary* args = [NSJSONSerialization JSONObjectWithData:data options:0 error:nullptr];
                if ([args isKindOfClass:[NSDictionary class]]) {
                    Execute(requestId, name, args);
                } else {
                    Fail(requestId, "invalid_argument", @"Некорректные JSON-параметры");
                }
            } @catch (NSException* exception) {
                Fail(requestId, "sdk_error", exception.name);
            } @finally {
                dispatch_semaphore_signal(capacity);
            }
        }
    });
    return true;
}

/// Очередь живёт до конца процесса. При остановке Lua ответы отбрасывает общий мост.
void FinalizePlatform() {}

}

#endif
