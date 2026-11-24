--- Вызов, принятый имитацией нативного моста.
---@class AppMetricaTestRequest
---@field operation string # Имя вызванной операции.
---@field args table<string, any> # Параметры до имитации кодирования в JSON.
---@field callback AppMetricaNativeCallback? # Обработчик, через который тест доставляет ответ.

--- Сведения об устройстве, используемые имитацией Defold.
---@class AppMetricaTestSystemInfo
---@field system_name string? # Имя платформы для проверки возможностей.
---@field language string? # Код языка для проверки каталога переводов.

---@type AppMetricaTestRequest[]
local queued = {}
local reject = false
local settings = {}
local system_name = "Android"
local encoded_args

sys = {}

--- Имитирует запрос платформы у Defold.
---@return AppMetricaTestSystemInfo # Текущая тестовая платформа.
function sys.get_sys_info()
    ---@type AppMetricaTestSystemInfo
    local info = { system_name = system_name }
    return info
end

--- Имитирует чтение проектной настройки.
---@param key string # Имя настройки в проекте.
---@return string? # Настроенное значение или nil.
function sys.get_config_string(key)
    return settings[key]
end

json = { null = {} }

--- Сохраняет исходные параметры для проверки передачи в SDK.
---@param args table<string, any> # Параметры, которые расширение пытается закодировать.
---@return string # Заглушка JSON, передаваемая имитации моста.
function json.encode(args)
    encoded_args = args
    return "{}"
end

--- Преобразует заранее определённые ответы в значения Lua.
---@param value string # Условное имя тестового ответа.
---@return boolean|AppMetricaStartupResult|string # Успех, идентификаторы или отложенная ссылка.
function json.decode(value)
    if value == "true" then
        return true
    end
    if value == "identifiers" then
        ---@type AppMetricaStartupResult
        local identifiers = { uuid = "demo" }
        return identifiers
    end
    if value == "link" then
        return "demo://level"
    end
    error("Некорректный JSON")
end

---@type AppMetricaNativeBridge
local native_mock = { available = true }

--- Принимает тестовый вызов или имитирует переполнение очереди.
---@param operation string # Имя операции нативного моста.
---@param _ string # Закодированные параметры. Тест проверяет оригинал из json.encode.
---@param callback? AppMetricaNativeCallback # Обработчик для имитации ответа SDK.
---@return boolean|nil # true при приёме либо nil при переполнении.
---@return string? # Код отказа или nil при приёме.
function native_mock.enqueue(operation, _, callback)
    if reject then
        return nil, "queue_full"
    end
    ---@type AppMetricaTestRequest
    local request = { operation = operation, args = encoded_args, callback = callback }
    queued[#queued + 1] = request
    return true
end

appmetrica_native = native_mock

--- Проверяет код немедленного отказа и наличие понятного сообщения.
---@param expected string # Ожидаемый код ошибки.
---@param result any # Результат вызова, который должен быть nil.
---@param err AppMetricaError? # Ошибка, которую должен вернуть вызов.
local function assert_error(expected, result, err)
    assert(result == nil and err and err.code == expected and type(err.message) == "string")
end

local sdk = dofile("qb-appmetrica/appmetrica.lua")
assert(sdk.is_supported())
assert(sdk.get_capabilities().deferred_deeplink)
assert_error("missing_api_key", sdk.activate())
settings["appmetrica.android_api_key"] = "from-config"
assert(sdk.activate({ automatic_sessions = false }))
assert(queued[1].operation == "activate" and queued[1].args.api_key == "from-config")
assert(queued[1].args.automatic_sessions == false)
assert(sdk.activate({ api_key = "override" }))
assert(queued[2].args.api_key == "override")

local response
--- Сохраняет идентификаторы, доставленные после постановки запроса в очередь.
---@param result AppMetricaStartupResult? # Ответ, доставленный имитацией моста.
---@param err AppMetricaError? # Ошибка, которой в этом сценарии быть не должно.
local function receive_identifiers(result, err)
    assert(not err)
    response = result
end

--- Прерывает тест, если отклонённый вызов всё же запустил обработчик.
---@param result any # Неожиданное значение ответа.
---@param err AppMetricaError? # Неожиданная ошибка в коллбеке.
local function unexpected_callback(result, err)
    error("Незапланированный коллбек")
end

assert(sdk.request_startup_params({ "uuid" }, receive_identifiers))
assert(response == nil and queued[3].operation == "startup")
queued[3].callback({}, "", "identifiers")
assert(response.uuid == "demo")
assert_error("invalid_argument", sdk.request_startup_params({ [2] = "uuid" }, unexpected_callback))
assert_error("invalid_argument", sdk.request_startup_params({ "uuid", "uuid" }, unexpected_callback))
assert_error("invalid_argument", sdk.request_startup_params({ "uuid" }))

local timed_out = false
--- Подтверждает, что тайм-аут передан в коллбек как ошибка.
---@param result AppMetricaStartupResult? # Результат запроса, который должен быть nil.
---@param err AppMetricaError? # Ошибка с кодом тайм-аута.
local function receive_timeout(result, err)
    assert_error("timeout", result, err)
    timed_out = true
end

assert(sdk.request_startup_params({ "uuid" }, receive_timeout))
queued[4].callback({}, "timeout", "SDK не вернул ответ")
assert(timed_out)
--- Сверяет доставленный URL с тестовой отложенной ссылкой.
---@param link string? # URL из ответа нативного моста.
---@param err AppMetricaError? # Ошибка, которой в этом сценарии быть не должно.
local function receive_link(link, err)
    assert(link == "demo://level" and not err)
end

assert(sdk.request_deferred_deeplink(receive_link))
queued[5].callback({}, "", "link")

local cycle = {}
cycle.self = cycle
assert_error("invalid_argument", sdk.report_event("cycle", cycle))
assert_error("invalid_argument", sdk.report_event("sparse_array", { data = { [2] = 1 } }))
assert_error("invalid_argument", sdk.report_event("mixed_array", { data = { [1] = 1, other = 2 } }))
assert_error("invalid_argument", sdk.report_event("non_number", { data = math.huge }))
assert(sdk.report_event("level_started", { level = 1, modes = { "classic", "hard" } }))

local reporter = assert(sdk.get_reporter("secondary"))
assert(sdk.activate_reporter("secondary", { session_timeout = 15 }))
assert(queued[#queued].operation == "activate_reporter" and queued[#queued].args.session_timeout == 15)
assert_error("invalid_argument", sdk.activate_reporter("secondary", { location_tracking = false }))
assert(reporter:report_revenue({ amount = "2.990001", currency = "USD" }))
assert(queued[#queued].args.reporter_key == "secondary" and queued[#queued].args.amount == "2.990001")
assert_error("invalid_argument", sdk.report_revenue({ amount = "1.0000001", currency = "USD" }))
assert(sdk.report_user_profile({
    { name = "finished_tutorial", type = "boolean", value = false },
    { name = "missions", type = "counter", operation = "increment", value = 1 },
    { name = "rank", type = "number", operation = "reset" },
}))
assert_error("invalid_argument", sdk.report_user_profile({ { name = "wins", type = "counter", operation = "reset" } }))
assert(sdk.report_ecommerce({ type = "purchase", order = {
    id = "order",
    items = { { product = { sku = "coins" }, quantity = 1, revenue = { amount = "2.99", currency = "USD" } } },
} }))
assert_error("invalid_argument", sdk.report_ecommerce({ type = "purchase", order = { id = "empty", items = {} } }))

reject = true
assert_error("queue_full", sdk.send_events_buffer(unexpected_callback))
system_name = "iPhone OS"
local ios = dofile("qb-appmetrica/appmetrica.lua")
assert(ios.is_supported() and not ios.get_capabilities().deferred_deeplink)
assert_error("unsupported_feature", ios.request_deferred_deeplink(unexpected_callback))
system_name = "Windows"
local desktop = dofile("qb-appmetrica/appmetrica.lua")
assert(not desktop.is_supported())
assert_error("unsupported_platform", desktop.activate())

--- Загружает каталог демонстрации, имитируя чтение ресурса и язык устройства в Defold.
---@param language string # Код языка, который имитирует тест.
---@return AppMetricaDemoLocalization # Загруженный каталог для указанного языка.
local function load_demo_locale(language)
    --- Возвращает язык тестового устройства.
    ---@return AppMetricaTestSystemInfo # Сведения с выбранным языком.
    function sys.get_sys_info()
        ---@type AppMetricaTestSystemInfo
        local info = { language = language }
        return info
    end

    --- Читает каталог по пути, который использует игра.
    ---@param path string # Путь ресурса внутри игры.
    ---@return string # Содержимое файла переводов.
    function sys.load_resource(path)
        assert(path == "/assets/locale/translations.csv")
        local csv = assert(io.open("assets/locale/translations.csv", "rb"))
        local content = csv:read("*a")
        csv:close()
        return content
    end

    return dofile("main/demo/localization.lua")
end

local russian = load_demo_locale("ru")
local english = load_demo_locale("en")
local fallback = load_demo_locale("fr")
local demo_key = "demo_game_running"
assert(russian.get(demo_key) == "Игровой цикл работает")
assert(english.get(demo_key) == "The game loop is running")
assert(fallback.get(demo_key) == english.get(demo_key))
print("Lua contract: OK")
