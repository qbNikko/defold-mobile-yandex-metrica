--- Предоставляет локализованные сообщения демонстрационной сцены.
---@class AppMetricaDemoLocalization

---@type AppMetricaDemoLocalization
local localization = {}
local TRANSLATIONS_PATH = "/assets/locale/translations.csv"

--- Переводы одной строки каталога сообщений демонстрации.
---@class AppMetricaDemoTranslation
---@field ru string # Русский перевод.
---@field en string # Английский перевод, используемый по умолчанию.

---@type table<string, AppMetricaDemoTranslation>
local translations = {}
local language = sys.get_sys_info().language
local source = assert(sys.load_resource(TRANSLATIONS_PATH))

-- Каталог демо содержит три колонки. Значения записываются без запятых и переносов строк.
for key, russian, english in source:gmatch("([^,\r\n]+),([^,\r\n]+),([^,\r\n]+)") do
    if key ~= "key" then
        ---@type AppMetricaDemoTranslation
        local translation = { ru = russian, en = english }
        translations[key] = translation
    end
end

--- Возвращает текст на языке устройства или английский перевод.
---@param key string # Ключ строки в каталоге демонстрации.
---@return string # Выбранный перевод или ключ при отсутствии строки.
function localization.get(key)
    local translation = translations[key]
    if not translation then
        return key
    end
    return language == "ru" and translation.ru or translation.en
end

return localization
