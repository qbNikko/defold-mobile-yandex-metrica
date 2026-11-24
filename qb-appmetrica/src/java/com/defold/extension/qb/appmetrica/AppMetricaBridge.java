package com.defold.extension.qb.appmetrica;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import io.appmetrica.analytics.AdRevenue;
import io.appmetrica.analytics.AdType;
import io.appmetrica.analytics.AppMetrica;
import io.appmetrica.analytics.AppMetricaConfig;
import io.appmetrica.analytics.DeferredDeeplinkListener;
import io.appmetrica.analytics.IReporter;
import io.appmetrica.analytics.ReporterConfig;
import io.appmetrica.analytics.Revenue;
import io.appmetrica.analytics.StartupParamsCallback;
import io.appmetrica.analytics.ecommerce.ECommerceEvent;
import io.appmetrica.analytics.profile.Attribute;
import io.appmetrica.analytics.profile.UserProfile;
import java.lang.ref.WeakReference;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Currency;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/** Выполняет команды AppMetrica последовательно в фоне и возвращает ответы через JNI. */
public final class AppMetricaBridge {
    private static final int QUEUE_CAPACITY = 256;
    private static final CommandQueue WORKER = new CommandQueue(QUEUE_CAPACITY);

    // Состояние SDK хранится на уровне процесса и меняется только в WORKER.
    private static String activeKey;
    private static boolean activationComplete;
    private static final Set<String> ACTIVE_REPORTERS = new HashSet<>();

    private final Application application;
    private final Context context;
    private final WeakReference<Activity> activity;

    /** Сохраняет контекст приложения и слабую ссылку на Activity Defold. */
    public AppMetricaBridge(Activity activity) {
        this.application = activity.getApplication();
        this.context = activity.getApplicationContext();
        this.activity = new WeakReference<>(activity);
    }

    /** Ставит команду с id и JSON-данными в очередь. Возвращает false при переполнении. */
    public boolean submit(long id, String operation, byte[] data) {
        return WORKER.offer(() -> execute(id, operation, data));
    }

    /** Вызывает SDK для команды и публикует ошибку, если выполнить её не удалось. */
    private void execute(long id, String operation, byte[] data) {
        try {
            JSONObject args = new JSONObject(new String(data, StandardCharsets.UTF_8));
            if ("activate".equals(operation)) {
                activate(id, args);
            } else if (!activationComplete) {
                reply(id, "activation_failed", "Предыдущая активация AppMetrica не завершилась успешно");
            } else {
                dispatch(id, operation, args);
            }
        } catch (Exception | LinkageError error) {
            reply(id, "sdk_error", error.getClass().getSimpleName());
        }
    }

    /** Активирует SDK с переданными настройками. Смена ключа требует перезапуска процесса. */
    private void activate(long id, JSONObject args) throws JSONException {
        String key = args.getString("api_key");
        if (activeKey != null && !activeKey.equals(key)) {
            reply(id, "already_activated", "SDK уже активирован с другим ключом");
            return;
        }
        if (activeKey == null) {
            activateSdk(key, args);
            activeKey = key;
        }
        if (!activationComplete) {
            if (args.optBoolean("automatic_sessions", true)) {
                AppMetrica.enableActivityAutoTracking(application);
            }
            activationComplete = true;
        }
        reply(id, null, "true");
    }

    /** Передаёт основной ключ и настройки в SDK. Ошибка оставляет ключ доступным для повторной попытки. */
    private void activateSdk(String key, JSONObject args) throws JSONException {
        AppMetricaConfig.Builder config = AppMetricaConfig.newConfigBuilder(key);
        if (args.has("data_sending_enabled")) config.withDataSendingEnabled(args.getBoolean("data_sending_enabled"));
        if (args.has("location_tracking")) config.withLocationTracking(args.getBoolean("location_tracking"));
        if (args.has("app_open_tracking")) config.withAppOpenTrackingEnabled(args.getBoolean("app_open_tracking"));
        if (args.has("session_timeout")) config.withSessionTimeout(args.getInt("session_timeout"));
        if (args.has("app_version")) config.withAppVersion(args.getString("app_version"));
        if (args.has("user_profile_id")) config.withUserProfileID(args.getString("user_profile_id"));
        if (args.has("crash_reporting")) config.withCrashReporting(args.getBoolean("crash_reporting"));
        if (args.optBoolean("logs_enabled")) config.withLogs();

        AppMetrica.activate(context, config.build());
    }

    /** Маршрутизирует команду к основному SDK или дополнительному репортёру. */
    private void dispatch(long id, String operation, JSONObject args) throws JSONException {
        if ("startup".equals(operation)) {
            startup(id, args.getJSONArray("keys"));
            return;
        }
        if ("deferred".equals(operation)) {
            deferred(id);
            return;
        }

        String reporterKey = args.optString("reporter_key", null);
        if (activeKey.equals(reporterKey)) {
            reply(id, "invalid_argument", "Ключ репортёра должен отличаться от основного");
            return;
        }
        if ("activate_reporter".equals(operation)) {
            activateReporter(id, reporterKey, args);
            return;
        }
        IReporter reporter = reporterKey == null ? null : AppMetrica.getReporter(context, reporterKey);
        if (reporter != null) ACTIVE_REPORTERS.add(reporterKey);
        switch (operation) {
            case "event": {
                String name = args.getString("name");
                JSONObject params = args.optJSONObject("params");
                if (reporter == null) AppMetrica.reportEvent(name, params == null ? null : params.toString());
                else reporter.reportEvent(name, params == null ? null : params.toString());
                break;
            }
            case "profile_id": {
                String profile = args.optString("value", null);
                if (reporter == null) AppMetrica.setUserProfileID(profile);
                else reporter.setUserProfileID(profile);
                break;
            }
            case "error":
                AppMetrica.reportError(args.getString("identifier"), args.getString("message"));
                break;
            case "profile": {
                UserProfile profile = userProfile(args.getJSONArray("attributes"));
                if (reporter == null) AppMetrica.reportUserProfile(profile);
                else reporter.reportUserProfile(profile);
                break;
            }
            case "ecommerce": {
                ECommerceEvent event = Commerce.event(args.getJSONObject("event"));
                if (reporter == null) AppMetrica.reportECommerce(event);
                else reporter.reportECommerce(event);
                break;
            }
            case "revenue": {
                Revenue revenue = revenue(args);
                if (reporter == null) AppMetrica.reportRevenue(revenue);
                else reporter.reportRevenue(revenue);
                break;
            }
            case "ad_revenue": {
                AdRevenue revenue = adRevenue(args);
                if (reporter == null) AppMetrica.reportAdRevenue(revenue);
                else reporter.reportAdRevenue(revenue);
                break;
            }
            case "send_events":
                if (reporter == null) AppMetrica.sendEventsBuffer();
                else reporter.sendEventsBuffer();
                break;
            case "data_sending":
                if (reporter == null) AppMetrica.setDataSendingEnabled(args.getBoolean("value"));
                else reporter.setDataSendingEnabled(args.getBoolean("value"));
                break;
            case "location_tracking":
                AppMetrica.setLocationTracking(args.getBoolean("value"));
                break;
            case "set_environment":
                AppMetrica.putAppEnvironmentValue(args.getString("key"), args.optString("value", null));
                break;
            case "clear_environment":
                AppMetrica.clearAppEnvironment();
                break;
            case "app_open":
                AppMetrica.reportAppOpen(new Intent(Intent.ACTION_VIEW, Uri.parse(args.getString("url"))));
                break;
            case "resume":
            case "pause":
                if (reporter != null) {
                    if ("resume".equals(operation)) reporter.resumeSession();
                    else reporter.pauseSession();
                } else {
                    Activity current = activity.get();
                    if (current == null) {
                        reply(id, "sdk_error", "Activity Defold недоступна");
                        return;
                    }
                    if ("resume".equals(operation)) AppMetrica.resumeSession(current);
                    else AppMetrica.pauseSession(current);
                }
                break;
            default:
                reply(id, "unsupported_feature", "Команда недоступна");
                return;
        }
        reply(id, null, "true");
    }

    /** Применяет настройки дополнительного SDK-репортёра до первого его использования. */
    private void activateReporter(long id, String key, JSONObject args) throws JSONException {
        if (ACTIVE_REPORTERS.contains(key)) {
            reply(id, "already_activated", "Репортёр уже используется");
            return;
        }
        ReporterConfig.Builder config = ReporterConfig.newConfigBuilder(key);
        if (args.has("data_sending_enabled")) config.withDataSendingEnabled(args.getBoolean("data_sending_enabled"));
        if (args.has("session_timeout")) config.withSessionTimeout(args.getInt("session_timeout"));
        if (args.has("user_profile_id")) config.withUserProfileID(args.getString("user_profile_id"));
        if (args.optBoolean("logs_enabled")) config.withLogs();
        AppMetrica.activateReporter(context, config.build());
        ACTIVE_REPORTERS.add(key);
        reply(id, null, "true");
    }

    /** Преобразует массив типизированных обновлений в профиль SDK. */
    private static UserProfile userProfile(JSONArray attributes) throws JSONException {
        UserProfile.Builder profile = UserProfile.newBuilder();
        for (int index = 0; index < attributes.length(); ++index) {
            JSONObject attribute = attributes.getJSONObject(index);
            String name = attribute.getString("name");
            boolean reset = "reset".equals(attribute.optString("operation"));
            switch (attribute.getString("type")) {
                case "string":
                    profile.apply(reset ? Attribute.customString(name).withValueReset()
                        : Attribute.customString(name).withValue(attribute.getString("value")));
                    break;
                case "number":
                    profile.apply(reset ? Attribute.customNumber(name).withValueReset()
                        : Attribute.customNumber(name).withValue(attribute.getDouble("value")));
                    break;
                case "boolean":
                    profile.apply(reset ? Attribute.customBoolean(name).withValueReset()
                        : Attribute.customBoolean(name).withValue(attribute.getBoolean("value")));
                    break;
                case "counter":
                    profile.apply(Attribute.customCounter(name).withDelta(attribute.getDouble("value")));
                    break;
                default:
                    throw new IllegalArgumentException("Неизвестный тип атрибута");
            }
        }
        return profile.build();
    }

    /** Создаёт отчёт о покупке с точной суммой в микродолях валюты. */
    private static Revenue revenue(JSONObject args) throws JSONException {
        long micros = new BigDecimal(args.getString("amount")).movePointRight(6).longValueExact();
        Revenue.Builder builder = Revenue.newBuilder(micros, Currency.getInstance(args.getString("currency")));
        if (args.has("quantity")) builder.withQuantity(args.getInt("quantity"));
        if (args.has("product_id")) builder.withProductID(args.getString("product_id"));
        if (args.has("payload")) builder.withPayload(args.getJSONObject("payload").toString());
        if (args.has("android_receipt")) {
            JSONObject receipt = args.getJSONObject("android_receipt");
            builder.withReceipt(Revenue.Receipt.newBuilder().withData(receipt.getString("data"))
                .withSignature(receipt.getString("signature")).build());
        }
        return builder.build();
    }

    /** Создаёт отчёт о доходе от рекламы с необязательными строковыми полями. */
    private static AdRevenue adRevenue(JSONObject args) throws JSONException {
        AdRevenue.Builder builder = AdRevenue.newBuilder(
            new BigDecimal(args.getString("amount")), Currency.getInstance(args.getString("currency"))
        );
        if (args.has("ad_network")) builder.withAdNetwork(args.getString("ad_network"));
        if (args.has("ad_type")) builder.withAdType(AdType.valueOf(args.getString("ad_type")));
        if (args.has("ad_unit_id")) builder.withAdUnitId(args.getString("ad_unit_id"));
        if (args.has("ad_unit_name")) builder.withAdUnitName(args.getString("ad_unit_name"));
        if (args.has("ad_placement_id")) builder.withAdPlacementId(args.getString("ad_placement_id"));
        if (args.has("ad_placement_name")) builder.withAdPlacementName(args.getString("ad_placement_name"));
        if (args.has("precision")) builder.withPrecision(args.getString("precision"));
        JSONObject payload = args.optJSONObject("payload");
        if (payload != null) {
            builder.withPayload(Commerce.fields(payload));
        }
        return builder.build();
    }

    /** Запрашивает идентификаторы SDK и публикует ответ штатного обработчика. */
    private void startup(long id, JSONArray keys) throws JSONException {
        Map<String, String> names = new HashMap<>();
        names.put("device_id", StartupParamsCallback.APPMETRICA_DEVICE_ID);
        names.put("device_id_hash", StartupParamsCallback.APPMETRICA_DEVICE_ID_HASH);
        names.put("uuid", StartupParamsCallback.APPMETRICA_UUID);
        List<String> requested = new ArrayList<>();
        for (int index = 0; index < keys.length(); ++index) {
            requested.add(names.get(keys.getString(index)));
        }
        AppMetrica.requestStartupParams(context, new StartupParamsCallback() {
            /** Возвращает только идентификаторы, запрошенные Lua. */
            @Override
            public void onReceive(Result result) {
                if (result == null) {
                    reply(id, "sdk_error", "SDK не вернул идентификаторы");
                    return;
                }
                try {
                    JSONObject values = new JSONObject();
                    if (requested.contains(APPMETRICA_DEVICE_ID)) values.put("device_id", result.deviceId);
                    if (requested.contains(APPMETRICA_DEVICE_ID_HASH)) values.put("device_id_hash", result.deviceIdHash);
                    if (requested.contains(APPMETRICA_UUID)) values.put("uuid", result.uuid);
                    reply(id, null, values.toString());
                } catch (JSONException error) {
                    reply(id, "sdk_error", "Не удалось сформировать ответ SDK");
                }
            }

            /** Возвращает причину ошибки SDK. */
            @Override
            public void onRequestError(Reason reason, Result result) {
                reply(id, "sdk_error", String.valueOf(reason));
            }
        }, requested);
    }

    /** Запрашивает отложенную ссылку первого запуска с помощью обработчика SDK. */
    private static void deferred(long id) {
        AppMetrica.requestDeferredDeeplink(new DeferredDeeplinkListener() {
            /** Возвращает URL в JSON-представлении. */
            @Override
            public void onDeeplinkLoaded(String deeplink) {
                reply(id, null, JSONObject.quote(deeplink));
            }

            /** Возвращает ошибку SDK без передачи исходного реферера в журнал. */
            @Override
            public void onError(Error error, String referrer) {
                reply(id, "sdk_error", error.getDescription());
            }
        });
    }

    /** Передаёт код и UTF-8-ответ в нативную очередь. */
    private static void reply(long id, String code, String payload) {
        complete(id, code, payload.getBytes(StandardCharsets.UTF_8));
    }

    /** Публикует результат у ожидающего id. Lua вызывается позже в игровом потоке. */
    private static native void complete(long id, String code, byte[] payload);
}
