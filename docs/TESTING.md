# Сборка и тестирование

## Локальные тесты

Из корня проекта выполните тест Lua-контракта с Lua 5.1 или LuaJIT.

```sh
lua tests/contract.lua
```

Для теста C++-очереди откройте `tests/CMakeLists.txt` в CLion или выполните команды из корня проекта.

```sh
cmake -S tests -B build/tests
cmake --build build/tests --config Debug
ctest --test-dir build/tests -C Debug --output-on-failure
```

Для Android-очереди достаточно JDK. В IntelliJ IDEA можно запустить `CommandQueueTest.main`, добавив каталоги с исходниками и тестом.

```powershell
New-Item -ItemType Directory -Force build/java-test | Out-Null
javac -encoding UTF-8 -d build/java-test qb-appmetrica/src/java/com/defold/extension/qb/appmetrica/CommandQueue.java tests/java/com/defold/extension/qb/appmetrica/CommandQueueTest.java
java -cp build/java-test com.defold.extension.qb.appmetrica.CommandQueueTest
```

Тест Android удерживает имитацию SDK в фоновом потоке. Пока она ждёт, вызывающий поток должен принять вторую команду и отклонить третью из-за переполнения, после чего команды завершаются по порядку.

## Проверка на Android и iOS

Сборка проекта и пересборка нативных зависимостей выполняются локально. Перед запуском из редактора проверьте настройку **Preferences → Extensions → Build Server** и убедитесь, что она указывает на локальный сервер.

1. Откройте `game.project` в Defold и задайте тестовый SDK-ключ для целевой платформы.
2. Соберите Android APK или iOS IPA с выбранной конфигурацией подписи. Для Android включите тип сборки **Release** и сохранение символов, чтобы проверить `mapping.txt`. В демонстрационном проекте R8 уже включён.
3. Запустите приложение на устройстве. Демо ставит событие и запрос в очередь сразу за командой `activate`. В журнале проверьте результат запроса `device_id_hash`. В отчётах тестового приложения проверьте событие `defold_appmetrica_demo`.
4. Повторите холодный запуск при медленной сети или без сети. Если запрашиваемый ID ещё не закэширован, во время ожидания журнал должен выводить растущий счётчик кадров. Запрос завершается результатом, ошибкой SDK либо `timeout`.
5. Проверьте отдельными запусками возврат из фона, завершение экземпляра скрипта до ответа, повторную активацию и несколько параллельных запросов. Для атрибуции сделайте чистую установку по тестовой трекинговой ссылке.

Используйте тот же сценарий проверки для APK и APK, полученного из AAB. Для iOS проверьте запуск на устройстве с iOS 15+ и наличие privacy manifest SDK в готовом пакете. Для отложенной ссылки Android требуется первая установка с подходящим реферером.

