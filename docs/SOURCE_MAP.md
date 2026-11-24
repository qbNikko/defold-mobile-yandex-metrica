# Карта исходников

| Путь | Что искать |
| --- | --- |
| `qb-appmetrica/appmetrica.lua` | Публичный Lua API, классы таблиц модуля и репортёра для LuaLS, аннотации моделей покупок и электронной коммерции. Валидация JSON и преобразование ответов в `result, err` |
| `qb-appmetrica/src/extension.cpp` | Регистрация Defold, приём команд, владение Lua-коллбеками, доставка за кадр и завершение Lua-контекста |
| `qb-appmetrica/src/inbox.h` | Допуск команд по состоянию активации, хранилище ожидающих запросов, тайм-аут и защита от повторной доставки |
| `qb-appmetrica/src/bridge.h` | Общий интерфейс платформенных адаптеров и публикации результата |
| `qb-appmetrica/src/android.cpp` | Загрузка Java-класса, JNI-сигнатуры, регистрация callback, передача UTF-8 |
| `qb-appmetrica/src/java/com/defold/extension/qb/appmetrica/AppMetricaBridge.java` | Android SDK, активация, отчёты, профили, настройки, запросы идентификаторов и отложенной ссылки. Ошибки запроса параметров запуска передаются в Lua как текст |
| `qb-appmetrica/src/java/com/defold/extension/qb/appmetrica/CommandQueue.java` | Последовательная фоновая очередь Android с ограничением вместимости |
| `qb-appmetrica/src/java/com/defold/extension/qb/appmetrica/Commerce.java` | JSON-модели электронной коммерции для Android |
| `qb-appmetrica/src/ios.mm` | Очередь iOS, SDK Core и Crashes, запрос идентификаторов, маршрутизация отчётов |
| `qb-appmetrica/src/commerce_ios.mm` | Модели электронной коммерции iOS |
| `qb-appmetrica/manifests/android` | Android Gradle-зависимость и правила Defold R8 |
| `qb-appmetrica/manifests/ios/Podfile` | Закреплённые CocoaPods-зависимости и минимальная iOS |
| `game.project`, `main/demo/` | Версия и каталог экспорта библиотеки, тестовый проект, счётчик кадров во время ожидания |
| `main/constants.lua` | Имя аналитического события демонстрации |
| `main/demo/localization.lua`, `assets/locale/translations.csv` | Локализованные сообщения демонстрации на русском и английском, выбор по языку устройства |
| `tests/contract.lua` | Контракт Lua с имитацией ответов нативного моста |
| `tests/inbox_test.cpp` | Допуск команд при активации, повторе и отказе. Регрессии повторного ответа, тайм-аута, переполнения и остановки |
| `tests/java/` | Тест Android-очереди на обычном JDK |
| `docs/qb-appmetrica-api.md` | Справочник 22 методов модуля и 10 методов репортёра с примерами |

Путь запроса проходит через Lua, общий нативный мост и очередь платформы. SDK публикует ответ в общее хранилище по ID запроса. `Update` забирает результат, восстанавливает экземпляр скрипта и вызывает Lua-обработчик. В адаптерах имя операции совпадает со строкой в вызове `submit` из Lua.
