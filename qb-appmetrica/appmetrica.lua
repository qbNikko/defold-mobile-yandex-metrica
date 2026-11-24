--- Ошибка проверки запроса, нативного моста или SDK.
---@class AppMetricaError
---@field code string # Стабильный код ошибки.
---@field message string # Диагностическое сообщение.

---@alias AppMetricaCommandCallback fun(result: boolean|nil, err: AppMetricaError|nil)
---@alias AppMetricaStartupKey "device_id"|"device_id_hash"|"uuid"
---@alias AppMetricaStartupCallback fun(result: AppMetricaStartupResult|nil, err: AppMetricaError|nil)
---@alias AppMetricaDeeplinkCallback fun(result: string|nil, err: AppMetricaError|nil)
---@alias AppMetricaNativeCallback fun(instance: table, code: string, response: string)
---@alias AppMetricaValidator fun(value: any): boolean

--- Внутренний Lua-интерфейс нативного расширения Defold.
---@class AppMetricaNativeBridge
---@field available boolean # Признак готовности нативного моста.
---@field enqueue fun(operation: string, payload: string, callback?: AppMetricaNativeCallback): boolean|nil, string? # Ставит JSON-запрос в очередь и возвращает признак приёма либо код отказа.

--- Оставшиеся лимиты проверки JSON одного вызова.
---@class AppMetricaJsonBudget
---@field bytes integer # Оставшееся число байтов для строк и ключей.
---@field entries integer # Оставшееся число элементов таблиц.

--- Идентификаторы установки и устройства.
---@class AppMetricaStartupResult
---@field device_id string? # Идентификатор устройства AppMetrica, если получен.
---@field device_id_hash string? # Хеш идентификатора устройства, если получен.
---@field uuid string? # Идентификатор установки, если получен.

--- Параметры отправки и сессий дополнительного репортёра.
---@class AppMetricaReporterOptions
---@field data_sending_enabled boolean? # Разрешение отправлять накопленные отчёты.
---@field logs_enabled boolean? # Разрешение записывать журналы SDK.
---@field session_timeout integer? # Максимальная пауза в сессии в секундах.
---@field user_profile_id string? # Идентификатор профиля при активации.

--- Настройки основного репортёра при активации.
---@class AppMetricaActivation: AppMetricaReporterOptions
---@field api_key string? # Ключ SDK. При отсутствии используется ключ платформы из проекта.
---@field location_tracking boolean? # Разрешение определять местоположение.
---@field app_open_tracking boolean? # Автоматический учёт открытий по ссылке.
---@field automatic_sessions boolean? # Автоматический учёт сессий.
---@field crash_reporting boolean? # Автоматическая отправка отчётов о сбоях.
---@field app_version string? # Версия приложения для отчётов.

--- Доступные возможности расширения в текущей сборке.
---@class AppMetricaCapabilities
---@field platform "android"|"ios"|nil # Мобильная платформа или nil на других платформах.
---@field supported boolean # Готовность моста на поддерживаемой платформе.
---@field startup_params boolean # Доступность запроса идентификаторов.
---@field deferred_deeplink boolean # Доступность запроса отложенной ссылки.
---@field reporters boolean # Доступность дополнительных репортёров.
---@field user_profiles boolean # Доступность обновления профилей.
---@field ecommerce boolean # Доступность событий электронной коммерции.
---@field revenue boolean # Доступность отчёта о покупке.
---@field ad_revenue boolean # Доступность отчёта о рекламном доходе.

--- Данные обработанной ошибки для аналитики.
---@class AppMetricaReportedError
---@field identifier string # Стабильный идентификатор группы ошибок.
---@field message string # Описание обработанной ошибки.

--- Данные и подпись чека Google Play.
---@class AppMetricaAndroidReceipt
---@field data string # Исходное содержимое чека.
---@field signature string # Подпись чека.

--- Данные чека App Store и идентификатор транзакции.
---@class AppMetricaIosReceipt
---@field data_base64 string # Чек в Base64.
---@field transaction_id string # Идентификатор транзакции.

--- Данные покупки и необязательный платформенный чек.
---@class AppMetricaPurchase
---@field amount string # Сумма десятичной строкой.
---@field currency string # Трёхбуквенный код валюты ISO 4217.
---@field quantity integer? # Количество единиц товара.
---@field product_id string? # Идентификатор товара в магазине.
---@field payload table<string, any>? # Дополнительные параметры покупки.
---@field android_receipt AppMetricaAndroidReceipt? # Чек для Android.
---@field ios_receipt AppMetricaIosReceipt? # Чек для iOS.

--- Доход от рекламного показа и параметры размещения.
---@class AppMetricaAdRevenue
---@field amount string # Сумма десятичной строкой.
---@field currency string # Трёхбуквенный код валюты ISO 4217.
---@field ad_type "NATIVE"|"BANNER"|"REWARDED"|"INTERSTITIAL"|"OTHER"|nil # Формат показа рекламы.
---@field ad_network string? # Название рекламной сети.
---@field ad_unit_id string? # Идентификатор рекламного блока.
---@field ad_unit_name string? # Название рекламного блока.
---@field ad_placement_id string? # Идентификатор места показа.
---@field ad_placement_name string? # Название места показа.
---@field precision string? # Степень точности оценки суммы.
---@field payload table<string, string>? # Дополнительные параметры показа.

--- Операция над пользовательским атрибутом.
---@class AppMetricaProfileAttribute
---@field name string # Имя атрибута.
---@field type "string"|"number"|"boolean"|"counter" # Тип значения атрибута.
---@field value string|number|boolean|nil # Новое значение или приращение. При сбросе поле опускается.
---@field operation "set"|"reset"|"increment"|nil # Операция над атрибутом. По умолчанию используется установка или приращение счётчика.

--- Экран магазина, с которым связано событие.
---@class AppMetricaCommerceScreen
---@field name string? # Название экрана.
---@field search_query string? # Поисковая строка на экране.
---@field categories string[]? # Путь по категориям от общей к конкретной.
---@field payload table<string, string>? # Строковые параметры экрана.

--- Часть цены во внутренней валюте.
---@class AppMetricaCommerceComponent
---@field amount string # Десятичная сумма во внутренней валюте.
---@field unit string # Название внутренней валюты.

--- Цена в денежной валюте с дополнительными компонентами.
---@class AppMetricaCommercePrice
---@field amount string # Денежная сумма десятичной строкой.
---@field currency string # Трёхбуквенный код валюты ISO 4217.
---@field components AppMetricaCommerceComponent[]? # Части цены во внутренних валютах.

--- Карточка товара для электронной коммерции.
---@class AppMetricaCommerceProduct
---@field sku string # Артикул товара.
---@field name string? # Название товара.
---@field categories string[]? # Путь по категориям товара.
---@field promo_codes string[]? # Промокоды товара.
---@field payload table<string, string>? # Строковые параметры товара.
---@field actual_price AppMetricaCommercePrice? # Цена продажи.
---@field original_price AppMetricaCommercePrice? # Цена до скидок.

--- Источник перехода к товару или позиции корзины.
---@class AppMetricaCommerceReferrer
---@field type string? # Тип источника перехода.
---@field identifier string? # Идентификатор источника перехода.
---@field screen AppMetricaCommerceScreen? # Экран, с которого пришёл пользователь.

--- Товар, количество и итоговая цена позиции корзины.
---@class AppMetricaCommerceItem
---@field product AppMetricaCommerceProduct # Данные товара.
---@field quantity integer # Количество единиц товара.
---@field revenue AppMetricaCommercePrice # Итоговая цена позиции с учётом количества и скидок.
---@field referrer AppMetricaCommerceReferrer? # Источник перехода.

--- Заказ с идентификатором и позициями корзины.
---@class AppMetricaCommerceOrder
---@field id string # Идентификатор заказа.
---@field items AppMetricaCommerceItem[] # Позиции корзины в порядке передачи.
---@field payload table<string, string>? # Строковые параметры заказа.

--- Действие пользователя в магазине и данные этого действия.
---@class AppMetricaCommerceEvent
---@field type "show_screen"|"show_product_card"|"show_product_details"|"add_cart_item"|"remove_cart_item"|"begin_checkout"|"purchase" # Тип действия в магазине.
---@field screen AppMetricaCommerceScreen? # Экран для просмотра магазина или карточки.
---@field product AppMetricaCommerceProduct? # Товар для просмотра карточки или деталей.
---@field referrer AppMetricaCommerceReferrer? # Необязательный источник перехода к деталям товара.
---@field item AppMetricaCommerceItem? # Позиция для добавления или удаления.
---@field order AppMetricaCommerceOrder? # Заказ для начала оформления или подтверждения покупки.

--- Публичный Lua-интерфейс активации, отчётности и запросов AppMetrica.
---@class AppMetricaModule
local appmetrica = {}

---@type AppMetricaNativeBridge?
local native = rawget(_G, "appmetrica_native")
local platforms = { Android = "android", ["iPhone OS"] = "ios" }
local platform = platforms[sys.get_sys_info().system_name]
local startup_keys = { device_id = true, device_id_hash = true, uuid = true }
local MAX_PAYLOAD_BYTES = 64 * 1024
local MAX_JSON_DEPTH = 16
local MAX_JSON_ENTRIES = 2048
local MAX_SIGNED_INT32 = 2147483647
local MIN_SESSION_SECONDS = 10
local MAX_AMOUNT_INTEGER_DIGITS = 12
local MAX_PURCHASE_FRACTION_DIGITS = 6
local MAX_AD_FRACTION_DIGITS = 12

local errors = {
    unsupported_platform = "AppMetrica доступна на Android и iOS",
    unsupported_feature = "Операция недоступна на этой платформе",
    bridge_unavailable = "Нативный мост AppMetrica недоступен",
    queue_full = "Очередь AppMetrica заполнена",
    payload_too_large = "Данные превышают предел 64 КБ",
    missing_api_key = "Укажите ключ AppMetrica для этой платформы",
    not_activated = "Сначала вызовите appmetrica.activate()",
    activation_failed = "AppMetrica не активировалась. Проверьте результат activate() и повторите вызов",
}

--- Возвращает nil и объект ошибки с кодом и сообщением.
---@param code string # Стабильный код ошибки.
---@param message string? # Текст ошибки или nil для сообщения по умолчанию.
---@return nil # Первый результат при отказе.
---@return AppMetricaError # Структура ошибки с кодом и сообщением.
local function fail(code, message)
    ---@type AppMetricaError
    local error_details = { code = code, message = message or errors[code] }
    return nil, error_details
end

--TODO: Перенести в qb
--- Проверяет, что значение является непустой строкой.
---@param value any # Значение для проверки на непустую строку.
---@return boolean # true, если значение прошло проверку.
local function is_nonempty_string(value)
    return type(value) == "string" and value ~= ""
end

--TODO: Перенести в qb
--- Проверяет целое число в заданном диапазоне для идентичных типов в Android и iOS.
---@param value any # Значение для проверки целочисленного диапазона.
---@param minimum integer # Минимально допустимое целое число.
---@return boolean # true, если значение прошло проверку.
local function is_bounded_integer(value, minimum)
    return type(value) == "number" and value >= minimum and value <= MAX_SIGNED_INT32 and value % 1 == 0
end

--- Проверяет глубину, размер и JSON-совместимость значения. Для корневого объекта запрещает числовые ключи.
---@param value any # Текущий узел дерева JSON.
---@param depth integer # Текущая глубина вложенности.
---@param budget AppMetricaJsonBudget # Оставшиеся лимиты проверки.
---@param visited table<table, boolean> # Таблицы на текущем пути обхода для обнаружения циклов.
---@param object boolean # Требовать только строковые ключи на текущем уровне.
---@return boolean # true, если значение прошло проверку.
local function valid_json(value, depth, budget, visited, object)
    local kind = type(value)
    if kind == "string" then
        budget.bytes = budget.bytes - #value
        return budget.bytes >= 0
    end
    if kind == "number" then
        return value > -math.huge and value < math.huge
    end
    if kind == "boolean" or value == json.null then
        return true
    end
    if kind ~= "table" or depth > MAX_JSON_DEPTH or visited[value] then
        return false
    end

    visited[value] = true
    local key_type, count, largest = nil, 0, 0
    for key, child in next, value do
        local current_type = type(key)
        budget.entries = budget.entries - 1
        if budget.entries < 0 or (key_type and key_type ~= current_type) then
            return false
        end
        if current_type == "string" then
            budget.bytes = budget.bytes - #key
        elseif not object and current_type == "number" and is_bounded_integer(key, 1) then
            largest = math.max(largest, key)
        else
            return false
        end
        if budget.bytes < 0 or not valid_json(child, depth + 1, budget, visited, false) then
            return false
        end
        key_type = current_type
        count = count + 1
    end
    visited[value] = nil
    return key_type ~= "number" or largest == count
end

--- Проверяет объект для отчёта. nil означает отсутствие параметров.
---@param value any # Параметры отчёта или nil.
---@return boolean # true, если значение прошло проверку.
local function valid_object(value)
    if value == nil then
        return true
    end
    if type(value) ~= "table" then
        return false
    end
    ---@type AppMetricaJsonBudget
    local budget = { bytes = MAX_PAYLOAD_BYTES, entries = MAX_JSON_ENTRIES }
    return valid_json(value, 1, budget, {}, true)
end

--- Проверяет поля параметров и собирает объект из поддерживаемых значений.
---@param value any # Таблица параметров для проверки по схеме.
---@param fields table<string, AppMetricaValidator> # Карта допустимых полей и функций их проверки.
---@return table|nil # Таблица проверенных полей или nil при ошибке.
---@return AppMetricaError? # Ошибка при отказе, иначе nil.
local function validate_fields(value, fields)
    if type(value) ~= "table" then
        return fail("invalid_argument", "Ожидается таблица параметров")
    end
    local result = {}
    for key, field in next, value do
        local validate = fields[key]
        if not validate or not validate(field) then
            return fail("invalid_argument", "Недопустимое поле: " .. tostring(key))
        end
        result[key] = field
    end
    return result
end

--- Возвращает true, когда текущая мобильная сборка загрузила нативный мост.
---@return boolean # true, если мобильная платформа поддерживается и нативный мост готов.
function appmetrica.is_supported()
    return platform ~= nil and native ~= nil and native.available == true
end

--- Возвращает платформу, состояние моста и доступность запросов и репортёров.
---@return AppMetricaCapabilities # Доступность возможностей в текущей сборке.
function appmetrica.get_capabilities()
    local supported = appmetrica.is_supported()
    ---@type AppMetricaCapabilities
    local capabilities = {
        platform = platform,
        supported = supported,
        startup_params = supported,
        deferred_deeplink = supported and platform == "android",
        reporters = supported,
        user_profiles = supported,
        ecommerce = supported,
        revenue = supported,
        ad_revenue = supported,
    }
    return capabilities
end

--- Передаёт команду в мост. Коллбек получает result, nil либо nil, err после возврата команды.
---@param operation string # Имя операции нативного моста.
---@param args table<string, any> # Параметры, передаваемые в SDK как JSON.
---@param callback AppMetricaCommandCallback|AppMetricaStartupCallback|AppMetricaDeeplinkCallback|nil # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
local function submit(operation, args, callback)
    if not platform then
        return fail("unsupported_platform")
    end
    if not appmetrica.is_supported() then
        return fail("bridge_unavailable")
    end
    if callback ~= nil and type(callback) ~= "function" then
        return fail("invalid_argument", "callback должен быть функцией")
    end
    if not valid_object(args) then
        return fail("invalid_argument", "Некорректные или слишком объёмные параметры JSON")
    end
    local encoded, payload = pcall(json.encode, args)
    if not encoded then
        return fail("invalid_argument", "Не удалось преобразовать параметры в JSON")
    end
    if #payload > MAX_PAYLOAD_BYTES then
        return fail("payload_too_large")
    end

    ---@type AppMetricaNativeCallback?
    local receive
    if callback then
        --- Преобразует ответ нативного моста в результат или ошибку Lua-запроса.
        ---@param _ table Экземпляр скрипта, переданный Defold.
        ---@param code string Код ошибки или пустая строка при успехе.
        ---@param response string JSON-результат или сообщение об ошибке.
        receive = function(_, code, response)
            if code ~= "" then
                local _, request_error = fail(code, response)
                callback(nil, request_error)
                return
            end
            local decoded, result = pcall(json.decode, response)
            if decoded then
                callback(result, nil)
            else
                local _, decode_error = fail("sdk_error", "Некорректный ответ AppMetrica")
                callback(nil, decode_error)
            end
        end
    end
    local accepted, code = native.enqueue(operation, payload, receive)
    if not accepted then
        return fail(code)
    end
    return true
end

--- Проверяет логический флаг.
---@param value any # Значение для проверки логического типа.
---@return boolean # true, если значение прошло проверку.
local function boolean(value)
    return type(value) == "boolean"
end

--- Проверяет длительность сессии в секундах.
---@param value any # Длительность сессии в секундах.
---@return boolean # true, если значение прошло проверку.
local function session_timeout(value)
    return is_bounded_integer(value, MIN_SESSION_SECONDS)
end

local activation_fields = {
    api_key = is_nonempty_string,
    data_sending_enabled = boolean,
    location_tracking = boolean,
    app_open_tracking = boolean,
    automatic_sessions = boolean,
    logs_enabled = boolean,
    session_timeout = session_timeout,
    app_version = is_nonempty_string,
    user_profile_id = is_nonempty_string,
    crash_reporting = boolean,
}

--- Активирует SDK с options (table|nil) и необязательным callback.
---@param options? AppMetricaActivation # Начальные настройки репортёра. При пропуске используются настройки по умолчанию.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.activate(options, callback)
    if not platform then
        return fail("unsupported_platform")
    end
    if not appmetrica.is_supported() then
        return fail("bridge_unavailable")
    end
    local args, err = validate_fields(options == nil and {} or options, activation_fields)
    if not args then
        return nil, err
    end
    args.api_key = args.api_key or sys.get_config_string("appmetrica." .. platform .. "_api_key")
    if not is_nonempty_string(args.api_key) then
        return fail("missing_api_key")
    end
    return submit("activate", args, callback)
end

--- Проверяет имя события, необязательный JSON-объект и маршрутизирует отчёт по ключу.
---@param reporter_key string? # Ключ дополнительного репортёра или nil для основного.
---@param name string # Имя аналитического события.
---@param params table<string, any>? # Необязательные параметры события.
---@param callback AppMetricaCommandCallback? # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
local function report_event(reporter_key, name, params, callback)
    if not is_nonempty_string(name) or (params ~= nil and type(params) ~= "table") or not valid_object(params) then
        return fail("invalid_argument", "Укажите имя события и допустимый JSON-объект")
    end
    return submit("event", { reporter_key = reporter_key, name = name, params = params }, callback)
end

--- Ставит пользовательское событие с именем и необязательными параметрами в очередь.
---@param name string # Имя аналитического события.
---@param params? table<string, any> # Необязательные параметры события.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.report_event(name, params, callback)
    return report_event(nil, name, params, callback)
end

--- Задаёт ID профиля (string) или очищает его (nil). Может принять ключ репортёра.
---@param reporter_key string? # Ключ дополнительного репортёра или nil для основного.
---@param value string? # ID профиля или nil для его очистки.
---@param callback AppMetricaCommandCallback? # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
local function set_profile(reporter_key, value, callback)
    if value ~= nil and not is_nonempty_string(value) then
        return fail("invalid_argument", "ID профиля должен быть непустой строкой или nil")
    end
    return submit("profile_id", { reporter_key = reporter_key, value = value }, callback)
end

--- Устанавливает ID профиля основной аналитики (string|nil).
---@param value string|nil # ID профиля или nil для его очистки.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.set_user_profile_id(value, callback)
    return set_profile(nil, value, callback)
end

--- Отправляет обработанную ошибку с полями identifier и message.
---@param value AppMetricaReportedError # Описание и идентификатор ошибки.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.report_error(value, callback)
    if type(value) ~= "table" or not is_nonempty_string(value.identifier) or not is_nonempty_string(value.message) then
        return fail("invalid_argument", "Укажите identifier и message ошибки")
    end
    return submit("error", { identifier = value.identifier, message = value.message }, callback)
end

--- Проверяет строковый код валюты ISO 4217 по форме.
---@param value any # Строка с кодом валюты.
---@return boolean # true, если значение прошло проверку.
local function currency(value)
    return type(value) == "string" and value:match("^[A-Z][A-Z][A-Z]$") ~= nil
end

--- Проверяет десятичную сумму без экспоненты и лишних знаков после точки.
---@param value any # Десятичная строка с суммой.
---@param fraction_limit integer # Допустимое число цифр после десятичной точки.
---@return boolean # true, если значение прошло проверку.
local function amount(value, fraction_limit)
    if type(value) ~= "string" then
        return false
    end
    local integer_part, fractional_part = value:match("^(%d+)%.(%d+)$")
    if integer_part then
        return #integer_part <= MAX_AMOUNT_INTEGER_DIGITS and #fractional_part <= fraction_limit
    end
    return #value <= MAX_AMOUNT_INTEGER_DIGITS and value:match("^%d+$") ~= nil
end

--- Проверяет целое положительное количество товара.
---@param value any # Количество единиц товара.
---@return boolean # true, если значение прошло проверку.
local function quantity(value)
    return is_bounded_integer(value, 1)
end

--- Проверяет сумму покупки в пределах шести знаков после точки.
---@param value any # Десятичная сумма покупки.
---@return boolean # true, если значение прошло проверку.
local function purchase_amount(value)
    return amount(value, MAX_PURCHASE_FRACTION_DIGITS)
end

--- Проверяет сумму рекламного дохода в пределах двенадцати знаков после точки.
---@param value any # Десятичная сумма рекламного дохода.
---@return boolean # true, если значение прошло проверку.
local function ad_amount(value)
    return amount(value, MAX_AD_FRACTION_DIGITS)
end

--- Проверяет строковую карту рекламных параметров.
---@param value any # Таблица строковых пар.
---@return boolean # true, если значение прошло проверку.
local function string_map(value)
    if type(value) ~= "table" then
        return false
    end
    local count = 0
    for key, item in next, value do
        count = count + 1
        if count > MAX_JSON_ENTRIES or type(key) ~= "string" or type(item) ~= "string" then
            return false
        end
    end
    return true
end

--TODO: Перенести в qb
--- Проверяет непустой плотный массив с ограничением на число элементов.
---@param value any # Таблица для проверки плотности массива.
---@param validate AppMetricaValidator # Функция проверки одного элемента массива.
---@return boolean # true, если значение прошло проверку.
local function array(value, validate)
    if type(value) ~= "table" then
        return false
    end
    local count, largest = 0, 0
    for index, item in next, value do
        count = count + 1
        if count > MAX_JSON_ENTRIES or not is_bounded_integer(index, 1) or not validate(item) then
            return false
        end
        largest = math.max(largest, index)
    end
    return count > 0 and count == largest
end

--- Проверяет непустой плотный массив строк.
---@param value any # Массив строк.
---@return boolean # true, если значение прошло проверку.
local function text_array(value)
    return array(value, is_nonempty_string)
end

--- Проверяет чек Google Play с исходными данными и подписью.
---@param value any # Чек Google Play.
---@return boolean # true, если значение прошло проверку.
local function android_receipt(value)
    return type(value) == "table" and is_nonempty_string(value.data) and is_nonempty_string(value.signature)
end

--- Проверяет обязательные поля чека App Store. Base64 декодируется в фоне.
---@param value any # Чек App Store.
---@return boolean # true, если значение прошло проверку.
local function ios_receipt(value)
    return type(value) == "table" and is_nonempty_string(value.data_base64) and is_nonempty_string(value.transaction_id)
end

local purchase_fields = {
    amount = purchase_amount, currency = currency, product_id = is_nonempty_string, quantity = quantity, payload = valid_object,
    android_receipt = android_receipt, ios_receipt = ios_receipt,
}
local ad_types = { NATIVE = true, BANNER = true, REWARDED = true, INTERSTITIAL = true, OTHER = true }

--- Проверяет общий для двух SDK тип рекламного формата.
---@param value any # Предполагаемый формат рекламы.
---@return boolean # true, если значение прошло проверку.
local function ad_type(value)
    return ad_types[value] == true
end

local ad_fields = {
    amount = ad_amount, currency = currency, payload = string_map, ad_network = is_nonempty_string,
    ad_type = ad_type, ad_unit_id = is_nonempty_string, ad_unit_name = is_nonempty_string,
    ad_placement_id = is_nonempty_string, ad_placement_name = is_nonempty_string, precision = is_nonempty_string,
}

--- Проверяет параметры дохода и ставит его в очередь.
---@param operation string # Имя операции нативного моста.
---@param reporter_key string? # Ключ дополнительного репортёра или nil для основного.
---@param value AppMetricaPurchase|AppMetricaAdRevenue # Сумма, валюта и другие данные денежного отчёта.
---@param fields table<string, AppMetricaValidator> # Карта допустимых полей и функций их проверки.
---@param callback AppMetricaCommandCallback? # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
local function report_money(operation, reporter_key, value, fields, callback)
    local args, err = validate_fields(value, fields)
    if not args then
        return nil, err
    end
    if not args.amount or not args.currency then
        return fail("invalid_argument", "Укажите amount и currency")
    end
    if (args.android_receipt and platform ~= "android") or (args.ios_receipt and platform ~= "ios") then
        return fail("unsupported_feature")
    end
    args.reporter_key = reporter_key
    return submit(operation, args, callback)
end

--- Отправляет данные о покупке. Сумма передаётся десятичной строкой.
---@param value AppMetricaPurchase # Данные покупки и необязательный чек.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.report_revenue(value, callback)
    return report_money("revenue", nil, value, purchase_fields, callback)
end

--- Отправляет доход от рекламы. Сумма передаётся десятичной строкой.
---@param value AppMetricaAdRevenue # Сумма и параметры рекламного показа.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.report_ad_revenue(value, callback)
    return report_money("ad_revenue", nil, value, ad_fields, callback)
end

--- Проверяет число, которое можно передать в JSON без потери конечности.
---@param value any # Значение для проверки конечности числа.
---@return boolean # true, если значение прошло проверку.
local function finite(value)
    return type(value) == "number" and value > -math.huge and value < math.huge
end

local profile_types = { string = is_nonempty_string, number = finite, boolean = boolean, counter = finite }

--- Проверяет тип, операцию и значение одного атрибута профиля.
---@param value any # Операция над атрибутом профиля.
---@return boolean # true, если значение прошло проверку.
local function attribute(value)
    if type(value) ~= "table" or not is_nonempty_string(value.name) or not profile_types[value.type] then
        return false
    end
    local operation = value.operation
    if value.type == "counter" then
        return (operation == nil or operation == "increment") and finite(value.value)
    end
    if operation == "reset" then
        return value.value == nil
    end
    return (operation == nil or operation == "set") and profile_types[value.type](value.value)
end

--- Ставит типизированные обновления пользовательского профиля в очередь нужного ключа.
---@param reporter_key string? # Ключ дополнительного репортёра или nil для основного.
---@param attributes AppMetricaProfileAttribute[] # Массив операций над атрибутами профиля.
---@param callback AppMetricaCommandCallback? # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
local function report_profile(reporter_key, attributes, callback)
    if not array(attributes, attribute) then
        return fail("invalid_argument", "Ожидается массив типизированных атрибутов")
    end
    return submit("profile", { reporter_key = reporter_key, attributes = attributes }, callback)
end

--- Отправляет массив типизированных обновлений профиля.
---@param attributes AppMetricaProfileAttribute[] # Массив операций над атрибутами профиля.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.report_user_profile(attributes, callback)
    return report_profile(nil, attributes, callback)
end

local screen_fields = { name = is_nonempty_string, search_query = is_nonempty_string, categories = text_array, payload = string_map }

--- Проверяет вложенный экран электронной коммерции.
---@param value any # Данные экрана магазина.
---@return boolean # true, если значение прошло проверку.
local function commerce_screen(value)
    return validate_fields(value, screen_fields) ~= nil
end

local referrer_fields = { type = is_nonempty_string, identifier = is_nonempty_string, screen = commerce_screen }

--- Проверяет описание источника перехода.
---@param value any # Поля источника перехода.
---@return boolean # true, если значение прошло проверку.
local function commerce_referrer(value)
    return validate_fields(value, referrer_fields) ~= nil
end

local component_fields = { amount = ad_amount, unit = is_nonempty_string }

--- Проверяет обязательные поля компонента цены.
---@param component any # Одна часть цены во внутренней валюте.
---@return boolean # true, если значение прошло проверку.
local function validate_component(component)
    local fields = validate_fields(component, component_fields)
    return fields ~= nil and fields.amount ~= nil and fields.unit ~= nil
end

--- Проверяет массив компонентов цены во внутренних единицах.
---@param value any # Массив компонентов цены.
---@return boolean # true, если значение прошло проверку.
local function components(value)
    return array(value, validate_component)
end

local price_fields = { amount = ad_amount, currency = currency, components = components }

--- Проверяет цену в валюте и её необязательные компоненты.
---@param value any # Данные цены в валюте и внутренних единицах.
---@return boolean # true, если значение прошло проверку.
local function price(value)
    local fields = validate_fields(value, price_fields)
    return fields ~= nil and fields.amount ~= nil and fields.currency ~= nil
end

local product_fields = {
    sku = is_nonempty_string, name = is_nonempty_string, categories = text_array, promo_codes = text_array, payload = string_map,
    actual_price = price, original_price = price,
}

--- Проверяет описание товара с обязательным SKU.
---@param value any # Данные товара с артикулом.
---@return boolean # true, если значение прошло проверку.
local function product(value)
    local fields = validate_fields(value, product_fields)
    return fields ~= nil and fields.sku ~= nil
end

local item_fields = { product = product, quantity = quantity, revenue = price, referrer = commerce_referrer }

--- Проверяет позицию корзины с товаром, количеством и полной ценой.
---@param value any # Данные позиции корзины.
---@return boolean # true, если значение прошло проверку.
local function cart_item(value)
    local fields = validate_fields(value, item_fields)
    return fields ~= nil and fields.product ~= nil and fields.quantity ~= nil and fields.revenue ~= nil
end

--- Проверяет непустой массив позиций корзины.
---@param value any # Массив позиций корзины.
---@return boolean # true, если значение прошло проверку.
local function cart_items(value)
    return array(value, cart_item)
end

local order_fields = { id = is_nonempty_string, items = cart_items, payload = string_map }

--- Проверяет заказ с идентификатором и позициями корзины.
---@param value any # Идентификатор заказа и его позиции.
---@return boolean # true, если значение прошло проверку.
local function order(value)
    local fields = validate_fields(value, order_fields)
    return fields ~= nil and fields.id ~= nil and fields.items ~= nil
end

local commerce_events = {
    show_screen = { required = { "screen" }, fields = { type = is_nonempty_string, screen = commerce_screen } },
    show_product_card = {
        required = { "product", "screen" }, fields = { type = is_nonempty_string, product = product, screen = commerce_screen },
    },
    show_product_details = {
        required = { "product" }, fields = { type = is_nonempty_string, product = product, referrer = commerce_referrer },
    },
    add_cart_item = { required = { "item" }, fields = { type = is_nonempty_string, item = cart_item } },
    remove_cart_item = { required = { "item" }, fields = { type = is_nonempty_string, item = cart_item } },
    begin_checkout = { required = { "order" }, fields = { type = is_nonempty_string, order = order } },
    purchase = { required = { "order" }, fields = { type = is_nonempty_string, order = order } },
}

--- Проверяет тип и вложенные модели электронной коммерции перед постановкой в очередь.
---@param reporter_key string? # Ключ дополнительного репортёра или nil для основного.
---@param event AppMetricaCommerceEvent # Тип события магазина и его данные.
---@param callback AppMetricaCommandCallback? # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
local function report_ecommerce(reporter_key, event, callback)
    local schema = type(event) == "table" and commerce_events[event.type]
    if not schema then
        return fail("invalid_argument", "Неизвестный тип события электронной коммерции")
    end
    if not valid_object(event) then
        return fail("invalid_argument", "Некорректные данные электронной коммерции")
    end
    local args, err = validate_fields(event, schema.fields)
    if not args then
        return nil, err
    end
    for _, field in ipairs(schema.required) do
        if not args[field] then
            return fail("invalid_argument", "Отсутствует обязательное поле: " .. field)
        end
    end
    return submit("ecommerce", { reporter_key = reporter_key, event = args }, callback)
end

--- Отправляет типизированное событие электронной коммерции.
---@param event AppMetricaCommerceEvent # Тип события магазина и его данные.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.report_ecommerce(event, callback)
    return report_ecommerce(nil, event, callback)
end

--- Ставит команду без дополнительных параметров для основного либо дополнительного ключа.
---@param operation string # Имя операции нативного моста.
---@param reporter_key string? # Ключ дополнительного репортёра или nil для основного.
---@param callback AppMetricaCommandCallback|AppMetricaDeeplinkCallback|nil # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
local function command(operation, reporter_key, callback)
    return submit(operation, { reporter_key = reporter_key }, callback)
end

--- Запрашивает отправку накопленных событий без ожидания сервера.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.send_events_buffer(callback)
    return command("send_events", nil, callback)
end

--- Возобновляет ручную сессию SDK.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.resume_session(callback)
    return command("resume", nil, callback)
end

--- Приостанавливает ручную сессию SDK.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.pause_session(callback)
    return command("pause", nil, callback)
end

--- Передаёт SDK логический флаг с заданным именем операции.
---@param operation string # Имя операции нативного моста.
---@param reporter_key string? # Ключ дополнительного репортёра или nil для основного.
---@param enabled boolean # Новое значение флага.
---@param callback AppMetricaCommandCallback? # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
local function set_flag(operation, reporter_key, enabled, callback)
    if not boolean(enabled) then
        return fail("invalid_argument", "Флаг должен быть логическим значением")
    end
    return submit(operation, { reporter_key = reporter_key, value = enabled }, callback)
end

--- Включает или отключает отправку накопленных данных SDK.
---@param enabled boolean # Новое значение флага.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.set_data_sending_enabled(enabled, callback)
    return set_flag("data_sending", nil, enabled, callback)
end

--- Включает или отключает определение местоположения средствами SDK.
---@param enabled boolean # Новое значение флага.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.set_location_tracking(enabled, callback)
    return set_flag("location_tracking", nil, enabled, callback)
end

--- Устанавливает значение окружения (string) или удаляет его (nil) по ключу.
---@param key string # Ключ параметра окружения.
---@param value string|nil # Строковое значение или nil для удаления.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.set_app_environment(key, value, callback)
    if not is_nonempty_string(key) or (value ~= nil and type(value) ~= "string") then
        return fail("invalid_argument", "Ожидаются строковый ключ и строка или nil")
    end
    return submit("set_environment", { key = key, value = value }, callback)
end

--- Удаляет все параметры окружения основной аналитики.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.clear_app_environment(callback)
    return command("clear_environment", nil, callback)
end

--- Учитывает открытие приложения по URL, переданному игрой.
---@param url string # URL открытия приложения со схемой.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.report_app_open(url, callback)
    if not is_nonempty_string(url) or not url:match("^[A-Za-z][A-Za-z0-9+%.%-]*:") then
        return fail("invalid_argument", "Требуется URL со схемой")
    end
    return submit("app_open", { url = url }, callback)
end

--- Запрашивает один или несколько идентификаторов. callback обязателен.
---@param keys AppMetricaStartupKey[] # Массив уникальных ключей запрашиваемых идентификаторов.
---@param callback AppMetricaStartupCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.request_startup_params(keys, callback)
    if type(keys) ~= "table" or type(callback) ~= "function" then
        return fail("invalid_argument", "Укажите массив ключей и callback")
    end
    local count, largest, seen = 0, 0, {}
    for index, key in next, keys do
        if not is_bounded_integer(index, 1) or not startup_keys[key] or seen[key] then
            return fail("invalid_argument", "Ожидается массив уникальных ключей device_id, device_id_hash, uuid")
        end
        largest = math.max(largest, index)
        count = count + 1
        seen[key] = true
    end
    if count == 0 or count ~= largest then
        return fail("invalid_argument", "Ожидается непустой массив без пропусков")
    end
    return submit("startup", { keys = keys }, callback)
end

--- Запрашивает отложенную ссылку первого запуска Android. callback обязателен.
---@param callback AppMetricaDeeplinkCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.request_deferred_deeplink(callback)
    if platform == "ios" then
        return fail("unsupported_feature")
    end
    if type(callback) ~= "function" then
        return fail("invalid_argument", "callback должен быть функцией")
    end
    return command("deferred", nil, callback)
end

local reporter_fields = {
    data_sending_enabled = boolean, logs_enabled = boolean,
    session_timeout = session_timeout, user_profile_id = is_nonempty_string,
}

--- Настраивает дополнительный репортёр до его первой команды.
---@param api_key string # Ключ SDK дополнительного репортёра.
---@param options? AppMetricaReporterOptions # Начальные настройки репортёра. При пропуске используются настройки по умолчанию.
---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
function appmetrica.activate_reporter(api_key, options, callback)
    if not is_nonempty_string(api_key) then
        return fail("invalid_argument", "Укажите ключ репортёра")
    end
    local args, err = validate_fields(options == nil and {} or options, reporter_fields)
    if not args then
        return nil, err
    end
    args.reporter_key = api_key
    return submit("activate_reporter", args, callback)
end

--- Создаёт Lua-репортёр для дополнительного ключа. SDK создаёт его при первой команде.
---@param api_key string # Ключ SDK дополнительного репортёра.
---@return AppMetricaReporter|nil # Дополнительный репортёр или nil при отказе.
---@return AppMetricaError? # Ошибка при отказе, иначе nil.
function appmetrica.get_reporter(api_key)
    if not appmetrica.is_supported() then
        return fail(platform and "bridge_unavailable" or "unsupported_platform")
    end
    if not is_nonempty_string(api_key) then
        return fail("invalid_argument", "Укажите ключ репортёра")
    end
    --- Репортёр, привязанный к отдельному ключу SDK.
    ---@class AppMetricaReporter
    local reporter = {}

    --- Ставит пользовательское событие репортёра в очередь.
    ---@param self AppMetricaReporter # Экземпляр репортёра, переданный при вызове метода.
    ---@param name string # Имя аналитического события.
    ---@param params? table<string, any> # Необязательные параметры события.
    ---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
    ---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
    ---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
    function reporter:report_event(name, params, callback)
        return report_event(api_key, name, params, callback)
    end

    --- Устанавливает или очищает ID профиля репортёра.
    ---@param self AppMetricaReporter # Экземпляр репортёра, переданный при вызове метода.
    ---@param value string|nil # ID профиля или nil для его очистки.
    ---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
    ---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
    ---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
    function reporter:set_user_profile_id(value, callback)
        return set_profile(api_key, value, callback)
    end

    --- Ставит обновления профиля репортёра в очередь.
    ---@param self AppMetricaReporter # Экземпляр репортёра, переданный при вызове метода.
    ---@param attributes AppMetricaProfileAttribute[] # Массив операций над атрибутами профиля.
    ---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
    ---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
    ---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
    function reporter:report_user_profile(attributes, callback)
        return report_profile(api_key, attributes, callback)
    end

    --- Ставит событие электронной коммерции в очередь репортёра.
    ---@param self AppMetricaReporter # Экземпляр репортёра, переданный при вызове метода.
    ---@param event AppMetricaCommerceEvent # Тип события магазина и его данные.
    ---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
    ---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
    ---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
    function reporter:report_ecommerce(event, callback)
        return report_ecommerce(api_key, event, callback)
    end

    --- Ставит отчёт о покупке в очередь репортёра.
    ---@param self AppMetricaReporter # Экземпляр репортёра, переданный при вызове метода.
    ---@param value AppMetricaPurchase # Данные покупки и необязательный чек.
    ---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
    ---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
    ---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
    function reporter:report_revenue(value, callback)
        return report_money("revenue", api_key, value, purchase_fields, callback)
    end

    --- Ставит отчёт о рекламном доходе в очередь репортёра.
    ---@param self AppMetricaReporter # Экземпляр репортёра, переданный при вызове метода.
    ---@param value AppMetricaAdRevenue # Сумма и параметры рекламного показа.
    ---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
    ---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
    ---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
    function reporter:report_ad_revenue(value, callback)
        return report_money("ad_revenue", api_key, value, ad_fields, callback)
    end

    --- Включает или отключает отправку данных репортёра.
    ---@param self AppMetricaReporter # Экземпляр репортёра, переданный при вызове метода.
    ---@param enabled boolean # Новое значение флага.
    ---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
    ---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
    ---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
    function reporter:set_data_sending_enabled(enabled, callback)
        return set_flag("data_sending", api_key, enabled, callback)
    end

    --- Запрашивает отправку буфера репортёра.
    ---@param self AppMetricaReporter # Экземпляр репортёра, переданный при вызове метода.
    ---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
    ---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
    ---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
    function reporter:send_events_buffer(callback)
        return command("send_events", api_key, callback)
    end

    --- Возобновляет ручную сессию репортёра.
    ---@param self AppMetricaReporter # Экземпляр репортёра, переданный при вызове метода.
    ---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
    ---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
    ---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
    function reporter:resume_session(callback)
        return command("resume", api_key, callback)
    end

    --- Приостанавливает ручную сессию репортёра.
    ---@param self AppMetricaReporter # Экземпляр репортёра, переданный при вызове метода.
    ---@param callback? AppMetricaCommandCallback # Обработчик результата или ошибки после возврата функции.
    ---@return boolean|nil accepted # true при приёме в очередь, иначе nil.
    ---@return AppMetricaError? error # Ошибка при отказе, иначе nil.
    function reporter:pause_session(callback)
        return command("pause", api_key, callback)
    end

    return reporter
end

return appmetrica
