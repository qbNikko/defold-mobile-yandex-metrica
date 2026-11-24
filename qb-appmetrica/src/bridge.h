#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

namespace appmetrica {

/// Инициализирует платформенный мост. Возвращает true, если мост доступен.
bool InitializePlatform();

/// Освобождает ресурсы игрового потока без ожидания фоновых работ.
void FinalizePlatform();

/// Передаёт команду в очередь адаптера. Данные JSON действительны до возврата функции.
bool Submit(uint64_t id, const char* operation, const char* json, size_t size);

/// Публикует результат из любого потока. Пустой code означает успех, payload содержит JSON.
void Complete(uint64_t id, std::string code, std::string payload);

}
