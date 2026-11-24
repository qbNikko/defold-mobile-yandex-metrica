#pragma once

#include "bridge.h"
#include <chrono>
#include <map>
#include <mutex>
#include <utility>

namespace appmetrica {

/// Принимает результаты фоновых задач и ограничивает число ожидающих запросов.
class Inbox {
public:
    using Clock = std::chrono::steady_clock;

    /// Результат завершения или ошибки команды.
    struct Result {
        std::string code;
        std::string payload;
    };

    /// Резервирует место для команды. Возвращает nullptr при приёме или код отказа.
    /// Для активации передайте activation=true. time_point::max() отключает тайм-аут.
    const char* Reserve(uint64_t id, Clock::time_point deadline, bool activation = false) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!activation && !activated_ && pendingActivations_ == 0) {
            return activationFailed_ ? "activation_failed" : "not_activated";
        }
        if (entries_.size() >= kCapacity || !entries_.emplace(id, Entry(deadline, activation)).second) {
            return "queue_full";
        }
        if (activation) {
            ++pendingActivations_;
        }
        return nullptr;
    }

    /// Записывает первый результат, если запрос ещё ожидается.
    void Publish(uint64_t id, Result result) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto entry = entries_.find(id);
        if (entry == entries_.end() || entry->second.ready || Clock::now() >= entry->second.deadline) {
            return;
        }
        if (entry->second.activation) {
            --pendingActivations_;
            activated_ = activated_ || result.code.empty();
            activationFailed_ = !activated_;
        }
        entry->second.result = std::move(result);
        entry->second.ready = true;
    }

    /// Забирает один готовый результат или тайм-аут. При занятой очереди возвращает false.
    bool Take(Clock::time_point now, uint64_t& id, Result& result) {
        std::unique_lock<std::mutex> lock(mutex_, std::try_to_lock);
        if (!lock.owns_lock()) {
            return false;
        }
        for (auto entry = entries_.begin(); entry != entries_.end(); ++entry) {
            if (entry->second.ready || now >= entry->second.deadline) {
                if (entry->second.activation && !entry->second.ready) {
                    --pendingActivations_;
                    activationFailed_ = !activated_;
                }
                id = entry->first;
                result = entry->second.ready
                    ? std::move(entry->second.result)
                    : Result{"timeout", "SDK не вернул ответ за отведённое время"};
                entries_.erase(entry);
                return true;
            }
        }
        return false;
    }

    /// Убирает один отклонённый запрос.
    void Remove(uint64_t id) {
        std::lock_guard<std::mutex> lock(mutex_);
        const auto entry = entries_.find(id);
        if (entry != entries_.end()) {
            if (entry->second.activation && !entry->second.ready) {
                --pendingActivations_;
            }
            entries_.erase(entry);
        }
    }

    /// Убирает все запросы при закрытии Lua-контекста.
    void Clear() {
        std::lock_guard<std::mutex> lock(mutex_);
        entries_.clear();
        pendingActivations_ = 0;
        activationFailed_ = false;
    }

private:
    /// Состояние ожидающего запроса.
    struct Entry {
        /// Создаёт запись со сроком ожидания ответа.
        Entry(Clock::time_point expires, bool activatesSdk) : deadline(expires), activation(activatesSdk), ready(false) {}
        Clock::time_point deadline;
        bool activation;
        bool ready;
        Result result;
    };

    static constexpr size_t kCapacity = 256;
    std::mutex mutex_;
    std::map<uint64_t, Entry> entries_;
    size_t pendingActivations_ = 0;
    bool activated_ = false;
    bool activationFailed_ = false;
};

}
