#include "../qb-appmetrica/src/inbox.h"
#include <cassert>
#include <thread>

using appmetrica::Inbox;

/// Проверяет допуск команд до, во время и после активации SDK, включая повторы и отказ очереди.
static void TestActivationAdmission() {
    Inbox inbox;
    const auto noDeadline = Inbox::Clock::time_point::max();

    assert(std::string(inbox.Reserve(1, noDeadline)) == "not_activated");
    assert(inbox.Reserve(2, noDeadline, true) == nullptr);
    inbox.Remove(2);
    assert(std::string(inbox.Reserve(3, noDeadline)) == "not_activated");

    assert(inbox.Reserve(4, noDeadline, true) == nullptr);
    assert(inbox.Reserve(5, noDeadline) == nullptr);
    inbox.Publish(4, {"sdk_error", "SDK отклонил активацию"});
    inbox.Publish(4, {"", "true"});
    assert(std::string(inbox.Reserve(6, noDeadline)) == "activation_failed");

    assert(inbox.Reserve(7, noDeadline, true) == nullptr);
    assert(inbox.Reserve(8, noDeadline, true) == nullptr);
    inbox.Publish(7, {"sdk_error", "Не удалось активировать SDK"});
    assert(inbox.Reserve(9, noDeadline) == nullptr);
    inbox.Publish(8, {"", "true"});
    assert(inbox.Reserve(10, noDeadline) == nullptr);

    assert(inbox.Reserve(11, noDeadline, true) == nullptr);
    inbox.Publish(11, {"already_activated", "Другой ключ"});
    assert(inbox.Reserve(12, noDeadline) == nullptr);

    inbox.Clear();
    assert(inbox.Reserve(13, noDeadline) == nullptr);
}

/// Проверяет отложенную доставку, порядок готовых ответов, тайм-аут и закрытие контекста.
int main() {
    TestActivationAdmission();
    Inbox inbox;
    const auto noDeadline = Inbox::Clock::time_point::max();
    uint64_t id = 0;
    Inbox::Result result;

    assert(inbox.Reserve(0, noDeadline, true) == nullptr);
    inbox.Publish(0, {"", "true"});
    assert(inbox.Take(Inbox::Clock::now(), id, result) && id == 0);
    assert(inbox.Reserve(1, noDeadline) == nullptr);
    assert(inbox.Reserve(2, noDeadline) == nullptr);
    assert(!inbox.Take(Inbox::Clock::now(), id, result));
    std::thread worker([&inbox] {
        inbox.Publish(2, {"", "\"ответ\""});
        inbox.Publish(2, {"sdk_error", "повтор"});
    });
    worker.join();
    assert(inbox.Take(Inbox::Clock::now(), id, result));
    assert(id == 2 && result.code.empty() && result.payload == "\"ответ\"");
    assert(!inbox.Take(Inbox::Clock::now(), id, result));

    assert(inbox.Reserve(3, Inbox::Clock::time_point::min()) == nullptr);
    inbox.Publish(3, {"", "true"});
    assert(inbox.Take(Inbox::Clock::now(), id, result));
    assert(id == 3 && result.code == "timeout");
    inbox.Clear();
    inbox.Publish(1, {"", "true"});
    assert(!inbox.Take(Inbox::Clock::now(), id, result));

    for (uint64_t request = 1; request <= 256; ++request) {
        assert(inbox.Reserve(request, noDeadline) == nullptr);
    }
    assert(std::string(inbox.Reserve(257, noDeadline)) == "queue_full");
    inbox.Remove(1);
    assert(inbox.Reserve(257, noDeadline) == nullptr);
}
