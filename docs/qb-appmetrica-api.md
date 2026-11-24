# Lua API qb-appmetrica

Подключите модуль и вызовите `activate()` при запуске игры. Функции модуля вызываются через точку, например `appmetrica.report_event(...)`. У дополнительного репортёра используется двоеточие, например `reporter:report_event(...)`.

## Как работают вызовы

В сигнатурах квадратные скобки обозначают необязательные аргументы. Если хотите передать коллбек, а предыдущий аргумент пропустить, поставьте на его место `nil`.

Запросы и команды SDK выполняются в фоне. Вызов сразу возвращает `true`, если команда принята в очередь, или `nil, err` при отказе. В случае отказа коллбек не вызывается. После выполнения коллбек получает `true, nil` для команды, `result, nil` для запроса или `nil, err` при ошибке. У `request_startup_params()` и `request_deferred_deeplink()` коллбек обязателен, время ожидания составляет до 30 секунд. `is_supported()`, `get_capabilities()` и `get_reporter()` возвращают результат сразу.

Для примеров ниже можно использовать такой обработчик:

```lua
local appmetrica = require("qb-appmetrica.appmetrica")

local function log_command_result(_, err)
    if err then
        print("AppMetrica", err.code, err.message)
    end
end
```

Успешная команда означает, что расширение передало её SDK. Доставку событий проверяйте в отчётах AppMetrica. Если SDK вернул ошибку и коллбек не задан, расширение пишет её в журнал.

| Код ошибки | Что произошло |
| --- | --- |
| `unsupported_platform`, `bridge_unavailable` | Платформа не поддерживается или мобильная сборка не загрузила нативный мост |
| `unsupported_feature` | Операция или формат данных недоступны на этой платформе |
| `missing_api_key`, `invalid_argument` | Нет SDK-ключа или переданы неверные аргументы |
| `not_activated`, `activation_failed` | Активация ещё не поставлена в очередь или завершилась ошибкой |
| `already_activated` | Основной SDK уже работает с другим ключом либо дополнительный репортёр уже используется |
| `queue_full`, `payload_too_large` | Очередь заполнена или данные превышают 64 КБ |
| `sdk_error`, `timeout` | SDK вернул ошибку или запрос не успел завершиться |

## Платформа и запуск SDK

### `is_supported()`

Возвращает `true`, если мобильная сборка загрузила нативный мост. Используйте, чтобы пропустить включение аналитики при запуске игры в редакторе или на настольной платформе. Этот метод проверяет доступность моста. Результат активации приходит в коллбек `activate()`.

```lua
if appmetrica.is_supported() then
    appmetrica.activate(nil, log_command_result)
end
```

### `get_capabilities()`

Возвращает `platform` со значением `"android"`, `"ios"` или `nil` и логические флаги `supported`, `startup_params`, `deferred_deeplink`, `reporters`, `user_profiles`, `ecommerce`, `revenue` и `ad_revenue`. Например, используйте `deferred_deeplink` перед запуском сценария получения ссылки после установки.

```lua
local capabilities = appmetrica.get_capabilities()
print(capabilities.platform, capabilities.deferred_deeplink)
```

### `activate([options[, callback]])`

Инициализирует SDK на старте игры. По умолчанию берёт `android_api_key` или `ios_api_key` из секции `[appmetrica]` в `game.project`. Все поля `options` необязательны. Повторный вызов с тем же ключом сохраняет текущие настройки. После неудачной активации можно вызвать `activate()` снова.

| Поле | Назначение |
| --- | --- |
| `api_key` | Ключ SDK для текущего запуска. Имеет приоритет над ключом проекта |
| `data_sending_enabled` | Начальный флаг отправки данных |
| `location_tracking` | Флаг определения местоположения |
| `app_open_tracking` | Флаг автоматического учёта открытий по ссылке |
| `automatic_sessions` | Флаг автоматического учёта сессий |
| `logs_enabled` | Флаг журналирования SDK |
| `crash_reporting` | Флаг автоматического сбора сбоев |
| `session_timeout` | Допустимая пауза в сессии в секундах. Целое число от 10 |
| `app_version` | Строка версии приложения для отчётов |
| `user_profile_id` | Идентификатор профиля с момента активации |

```lua
local queued, err = appmetrica.activate({
    data_sending_enabled = true,
    location_tracking = false,
}, log_command_result)

if queued then
    appmetrica.report_event("game_started")
else
    print(err.code, err.message)
end
```

## Игровые события, ошибки и профили

### `report_event(name[, params[, callback]])`

Отправляет игровое действие в отчёт **События**. В отчёте можно, например, посчитать, сколько игроков дошли до конца обучения. `name` — непустая строка, `params` — JSON-совместимая таблица со строковыми ключами. Вложенные объекты и плотные массивы от индекса 1 сохраняют структуру. Пустая таблица станет объектом `{}`. Для явного JSON `null` передайте `json.null`. Вложенность таблиц ограничена 16 уровнями.

```lua
appmetrica.report_event("treasure_found", {
    location = "lagoon",
    treasure = { kind = "chest", rarity = "rare" },
    coins = 50,
}, log_command_result)
```

Для события без параметров передайте `nil` перед коллбеком. Пример вызова — `appmetrica.report_event("tutorial_finished", nil, log_command_result)`.

### `report_error(value[, callback])`

Отправляет обработанную ошибку. Используйте, если игра перехватила сбой чтения сохранения и смогла продолжить с резервной копией. `identifier` — стабильное имя группы ошибок, `message` — описание произошедшего.

```lua
appmetrica.report_error({
    identifier = "save_read_failed",
    message = "Игра восстановила состояние из резервной копии",
}, log_command_result)
```

### `set_user_profile_id(value[, callback])`

Связывает последующие данные с известным ID игрока. Используйте после входа в аккаунт, чтобы отчёты относились к его профилю, и передайте `nil` при выходе, чтобы очистить заданный ID.

```lua
appmetrica.set_user_profile_id("player_90371")
-- При выходе из аккаунта.
appmetrica.set_user_profile_id(nil)
```

### `report_user_profile(attributes[, callback])`

Обновляет атрибуты профиля. Используйте для состояния игрока, например выбранного режима, окончания обучения или числа завершённых экспедиций. Передайте непустой массив записей с `name`, `type`, `value` и необязательным `operation`.

| Тип | Операции |
| --- | --- |
| `string`, `number`, `boolean` | `set` или `reset`. По умолчанию используется `set`. При `reset` поле `value` опускается |
| `counter` | `increment`. Передайте числовое приращение в `value` |

```lua
appmetrica.report_user_profile({
    { name = "favorite_mode", type = "string", value = "exploration" },
    { name = "tutorial_finished", type = "boolean", value = true },
    { name = "expeditions_completed", type = "counter", operation = "increment", value = 1 },
    { name = "old_rank", type = "number", operation = "reset" },
})
```

## Доход и магазин

### `report_revenue(value[, callback])`

Передаёт подтверждённую покупку за деньги. Вызывайте из обработчика успешного платежа. Обязательны `amount` как десятичная строка и `currency` как код ISO 4217. Цена указывается за единицу товара, а `quantity` задаёт количество. Можно передать `product_id` и JSON-объект `payload`.

```lua
appmetrica.report_revenue({
    amount = "2.99",
    currency = "USD",
    product_id = "coins_small",
    quantity = 1,
    payload = { source = "ship_shop" },
}, log_command_result)
```

Для проверки покупки SDK принимает `android_receipt = { data, signature }` на Android и `ios_receipt = { data_base64, transaction_id }` на iOS. Сумма допускает до 12 цифр целой части и до 6 после точки.

### `report_ad_revenue(value[, callback])`

Передаёт денежный доход от рекламного показа. Например, вызывайте при получении от рекламной сети суммы за просмотр ролика с наградой. Обязательны `amount` и `currency`. В `amount` допускается до 12 цифр целой части и до 12 после точки.

```lua
appmetrica.report_ad_revenue({
    amount = "0.00321",
    currency = "USD",
    ad_type = "REWARDED",
    ad_network = "reward_provider",
    ad_unit_id = "extra_dive",
    payload = { reward = "extra_attempt" },
}, log_command_result)
```

Форматы `ad_type` — `NATIVE`, `BANNER`, `REWARDED`, `INTERSTITIAL`, `OTHER`. Можно указать `ad_unit_name`, `ad_placement_id`, `ad_placement_name` и `precision`. В `payload` ключи и значения должны быть строками.

### `report_ecommerce(event[, callback])`

Передаёт этапы взаимодействия с магазином. Например, по просмотрам товаров и оформленным заказам можно понять, на каком шаге игрок уходит из магазина. Разместите каждый вызов из примера в обработчике соответствующего действия.

| `event.type` | Поля | Пример использования |
| --- | --- | --- |
| `show_screen` | `screen` | Игрок открыл корабельный магазин |
| `show_product_card` | `product`, `screen` | Карточка товара появилась на экране каталога |
| `show_product_details` | `product` и необязательный `referrer` | Игрок открыл описание товара |
| `add_cart_item` | `item` | Товар добавлен в корзину |
| `remove_cart_item` | `item` | Товар удалён из корзины |
| `begin_checkout` | `order` | Игрок начал оформление заказа |
| `purchase` | `order` | Заказ подтверждён |

```lua
local screen = { name = "ship_shop", categories = { "upgrades" } }
local price = { amount = "4.99", currency = "USD" }
local product = { sku = "diving_gear", name = "Водолазное снаряжение", actual_price = price }
local item = { product = product, quantity = 1, revenue = price }
local order = { id = "order_1742", items = { item } }

appmetrica.report_ecommerce({ type = "show_screen", screen = screen })
appmetrica.report_ecommerce({ type = "show_product_card", product = product, screen = screen })
appmetrica.report_ecommerce({ type = "show_product_details", product = product })
appmetrica.report_ecommerce({ type = "add_cart_item", item = item })
-- Вызовите этот метод только при фактическом удалении позиции.
appmetrica.report_ecommerce({ type = "remove_cart_item", item = item })
-- Вызовите следующие методы на соответствующих этапах оформления и оплаты.
appmetrica.report_ecommerce({ type = "begin_checkout", order = order })
appmetrica.report_ecommerce({ type = "purchase", order = order })
```

| Модель | Обязательные поля | Необязательные поля |
| --- | --- | --- |
| Экран | — | `name`, `search_query`, `categories`, `payload` |
| Товар | `sku` | `name`, `categories`, `promo_codes`, `payload`, `actual_price`, `original_price` |
| Цена | `amount`, `currency` | `components` с элементами `{ amount, unit }` для внутренних валют |
| Источник перехода | — | `type`, `identifier`, `screen` |
| Позиция | `product`, целое `quantity` от 1, `revenue` | `referrer` |
| Заказ | `id`, непустой массив `items` | `payload` |

Поля `categories` и `promo_codes` принимают массивы строк, а `payload` — строковые пары. Суммы передавайте десятичными строками с той же точностью, что и рекламный доход. `revenue` позиции задаёт полную цену с учётом количества и скидок. В примере она равна цене товара, потому что количество равно 1.

## Отправка, сессии и окружение

### `set_data_sending_enabled(enabled[, callback])`

Передаёт SDK логический флаг отправки отчётов. Используйте, когда пользователь меняет настройку отправки аналитики. Начальное состояние задаётся параметром `data_sending_enabled` при активации.

```lua
appmetrica.set_data_sending_enabled(false, log_command_result)
```

### `set_location_tracking(enabled[, callback])`

Управляет определением местоположения в SDK. Например, отключите этот режим, когда пользователь отключает использование геолокации для аналитики.

```lua
appmetrica.set_location_tracking(false, log_command_result)
```

### `send_events_buffer([callback])`

Просит SDK отправить накопленные отчёты. Например, при диагностике можно запросить отправку сразу после тестового события, чтобы быстрее проверить его в кабинете.

```lua
appmetrica.report_event("analytics_test")
appmetrica.send_events_buffer(log_command_result)
```

### `resume_session([callback])` и `pause_session([callback])`

Возобновляют и приостанавливают ручную сессию. Вызывайте их из обработчиков перехода игры на передний план и в фон. Для основного SDK задайте `automatic_sessions = false` при активации.

```lua
appmetrica.activate({ automatic_sessions = false })
-- Когда игра переходит в активное состояние.
appmetrica.resume_session()
-- Когда игра приостанавливается.
appmetrica.pause_session()
```

### `set_app_environment(key, value[, callback])`

Добавляет строковое значение к окружению будущих отчётов. Например, укажите канал сборки один раз перед отправкой серии событий. Передайте `nil` вместо значения, чтобы удалить одно поле.

```lua
appmetrica.set_app_environment("build_channel", "beta")
-- Когда значение больше не применяется.
appmetrica.set_app_environment("build_channel", nil)
```

### `clear_app_environment([callback])`

Удаляет все значения, заданные через `set_app_environment()`.

```lua
appmetrica.clear_app_environment(log_command_result)
```

## Ссылки и идентификаторы

### `report_app_open(url[, callback])`

Передаёт SDK URL, по которому открыли игру. Подходит, когда ссылка уже доставлена в ваш обработчик и открытие нужно зарегистрировать вручную. URL должен содержать схему.

```lua
appmetrica.report_app_open("treasuregame://event/summer", log_command_result)
```

### `request_startup_params(keys, callback)`

Запрашивает `device_id`, `device_id_hash` или `uuid`. Передайте непустой массив уникальных ключей. В коллбек приходит таблица с доступными значениями. Например, `device_id_hash` полезен для поиска событий конкретного тестового устройства в выгрузке AppMetrica.

```lua
local queued, err = appmetrica.request_startup_params({ "device_id_hash", "uuid" }, function(result, request_error)
    if request_error then
        print(request_error.code, request_error.message)
        return
    end
    print("AppMetrica Device ID получен", result.device_id_hash ~= nil)
end)

if not queued then
    print(err.code, err.message)
end
```

### `request_deferred_deeplink(callback)`

**Только Android.** Запрашивает отложенный URL после первого запуска с подходящим реферером установки. Например, после установки по рекламной ссылке можно открыть экран акции. Проверьте `get_capabilities().deferred_deeplink`. Успех передаёт строку URL в коллбек, отказ — объект ошибки.

```lua
if appmetrica.get_capabilities().deferred_deeplink then
    appmetrica.request_deferred_deeplink(function(url, err)
        if err then
            print(err.code, err.message)
            return
        end
        if url == "treasuregame://event/summer" then
            print("Открыть экран сезонного события")
        end
    end)
end
```

## Дополнительный репортёр

Используйте отдельный SDK-ключ, чтобы отправлять часть отчётов в другое приложение AppMetrica. Например, отделите аналитику тестовой версии магазина от основной статистики. Ключ дополнительного репортёра должен отличаться от основного.

### `activate_reporter(api_key[, options[, callback]])`

Задаёт настройки дополнительного репортёра. Вызовите после `activate()` и до первой команды с этим ключом. Допустимые поля — `data_sending_enabled`, `logs_enabled`, `session_timeout` и `user_profile_id`.

```lua
local reporter_key = "ВАШ_ДОПОЛНИТЕЛЬНЫЙ_SDK_КЛЮЧ"
appmetrica.activate_reporter(reporter_key, {
    logs_enabled = true,
    session_timeout = 60,
}, log_command_result)
```

### `get_reporter(api_key)`

Возвращает Lua-объект репортёра или `nil, err`. SDK создаёт репортёр при первой обращённой к нему команде, если он ещё не настроен. Сохраните объект и используйте его для отчётов по дополнительному ключу.

```lua
local reporter_key = "ВАШ_ДОПОЛНИТЕЛЬНЫЙ_SDK_КЛЮЧ"
local reporter, err = appmetrica.get_reporter(reporter_key)
if reporter then
    reporter:report_event("shop_beta_opened")
else
    print(err.code, err.message)
end
```

### Методы объекта репортёра

Параметры, коллбек и ошибки работают так же, как у одноимённых основных методов. В следующих примерах `reporter` — объект, полученный через `get_reporter`.

| Метод | Сценарий | Пример |
| --- | --- | --- |
| `reporter:report_event(name[, params[, callback]])` | Событие для дополнительной статистики | `reporter:report_event("shop_beta_opened", { screen = "upgrades" })` |
| `reporter:set_user_profile_id(value[, callback])` | Привязать отчёты этого репортёра к профилю. Для очистки передать `nil` | `reporter:set_user_profile_id("player_90371")` |
| `reporter:report_user_profile(attributes[, callback])` | Передать атрибут профиля в отдельную аналитику | `reporter:report_user_profile({ { name = "shop_beta", type = "boolean", value = true } })` |
| `reporter:report_revenue(value[, callback])` | Зарегистрировать покупку по дополнительному ключу | `reporter:report_revenue({ amount = "2.99", currency = "USD", product_id = "coins_small" })` |
| `reporter:report_ad_revenue(value[, callback])` | Зарегистрировать доход от рекламного показа | `reporter:report_ad_revenue({ amount = "0.00321", currency = "USD", ad_type = "REWARDED" })` |
| `reporter:report_ecommerce(event[, callback])` | Собрать этапы воронки отдельного магазина | `reporter:report_ecommerce({ type = "show_screen", screen = { name = "shop_beta" } })` |
| `reporter:set_data_sending_enabled(enabled[, callback])` | Изменить флаг отправки для этого репортёра | `reporter:set_data_sending_enabled(false)` |
| `reporter:send_events_buffer([callback])` | Запросить отправку отчётов дополнительного репортёра | `reporter:send_events_buffer(log_command_result)` |
| `reporter:resume_session([callback])` | Возобновить ручную сессию дополнительного репортёра | `reporter:resume_session()` |
| `reporter:pause_session([callback])` | Приостановить ручную сессию дополнительного репортёра | `reporter:pause_session()` |
