# qb-appmetrica

Расширение для Defold отправляет данные игры в Яндекс AppMetrica. С его помощью можно считать запуски и игровые события, собирать ошибки, вести профили игроков и учитывать покупки и доход от рекламы. Запросы к SDK выполняются в фоне, ответы приходят в коллбеки Lua.

| Платформа | SDK |
| --- | --- |
| Android | AppMetrica 8.6.0 |
| iOS 15 и новее | AppMetricaCore и AppMetricaCrashes 7.0.0 |

На Windows, macOS, Linux и HTML5 аналитика через это расширение недоступна.

## Подключение к Defold

- **Из ZIP.** Скопируйте ссылку на [версию 1.0](https://github.com/qbNikko/defold-mobile-yandex-metrica/archive/refs/tags/1.0.zip) в **Project → Dependencies** в `game.project`, затем выполните **Project → Fetch Libraries**.
- **Из исходников.** Скопируйте папку `qb-appmetrica` рядом с `game.project` вашей игры. Если расширение было подключено через ZIP, уберите его из списка зависимостей.

Если редактируете `game.project` вручную, добавьте зависимость в секцию `[project]`:

```ini
[project]
dependencies#0 = https://github.com/qbNikko/defold-mobile-yandex-metrica/archive/refs/tags/1.0.zip
```

Если в проекте уже есть зависимости, используйте следующий свободный номер вместо `#0`.

В обоих случаях модуль подключается одинаково:

```lua
local appmetrica = require("qb-appmetrica.appmetrica")
```

Для Android с R8 используйте Defold 1.13.2 или новее. В поле **Android → R8 Keep Rules** укажите `/builtins/manifests/android/dmengine.keep` либо оставьте свои правила проекта, если они уже настроены. Правила для Java-моста находятся в `qb-appmetrica/manifests/android/appmetrica.keep`. Зависимости iOS перечислены в Podfile расширения.

## Настройка AppMetrica

1. Добавьте игру в [кабинете AppMetrica](https://appmetrica.yandex.ru/). В настройках приложения откройте **Основное** и скопируйте **API key (для SDK)**.
2. Впишите ключ в `game.project`. Если Android и iOS должны попадать в один отчёт, используйте один и тот же ключ для обеих платформ. Для сборки на одной платформе достаточно заполнить её поле.

```ini
[appmetrica]
android_api_key = ВАШ_SDK_КЛЮЧ
ios_api_key = ВАШ_SDK_КЛЮЧ
```

Для тестовой сборки можно переопределить ключ в Lua через `appmetrica.activate({ api_key = "ТЕСТОВЫЙ_SDK_КЛЮЧ" })`.

## Первое событие

Вызовите `activate()` один раз при запуске игры. Как только активация поставлена в очередь, можно отправлять события. Расширение дождётся результата активации в фоне.

```lua
local appmetrica = require("qb-appmetrica.appmetrica")

local function log_error(_, err)
    if err then
        print("AppMetrica", err.code, err.message)
    end
end

function init(self)
    if not appmetrica.is_supported() then
        return
    end

    local accepted, err = appmetrica.activate(nil, log_error)
    if not accepted then
        log_error(nil, err)
        return
    end

    local queued, event_error = appmetrica.report_event("game_start", {
        source = "cold_start",
    }, log_error)
    if not queued then
        log_error(nil, event_error)
    end
end
```

Запустите мобильную сборку и найдите `game_start` в отчёте **Продукт → События** в AppMetrica. Параметр `source` можно посмотреть в группировках отчёта. SDK отправляет события пакетами, поэтому они могут появиться с задержкой.

- [Справочник Lua API с примерами](docs/qb-appmetrica-api.md)
- [Тесты и проверка на устройстве](docs/TESTING.md)
- [Настройки приложения в AppMetrica](https://appmetrica.yandex.ru/docs/ru/settings/general)

## Лицензия

`qb-appmetrica` распространяется по [лицензии MIT](LICENSE). На сторонние зависимости распространяются их собственные лицензии.
