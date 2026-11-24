#include <dmsdk/sdk.h>
#include "inbox.h"
#include <cstring>
#include <map>

namespace appmetrica {

#if defined(DM_PLATFORM_ANDROID) || defined(DM_PLATFORM_IOS)

// Очередь доступна SDK до завершения процесса, в том числе после закрытия Lua.
static Inbox* const inbox = new Inbox();
static std::map<uint64_t, dmScript::LuaCallbackInfo*> callbacks;
static uint64_t nextId = 0;
static bool available = false;
static const size_t kMaxPayload = 64 * 1024;
static const unsigned kMaxCompletionsPerFrame = 16;
static const unsigned kStartupTimeoutSeconds = 30;

/// Публикует ограниченный по размеру ответ без обращения к Lua.
void Complete(uint64_t id, std::string code, std::string payload) {
    if (payload.size() > kMaxPayload) {
        code = "sdk_error";
        payload = "Ответ SDK превышает допустимый размер";
    }
    inbox->Publish(id, {std::move(code), std::move(payload)});
}

/// Принимает Lua-команду (имя, JSON, обработчик или nil), возвращает true или nil и код ошибки.
static int Enqueue(lua_State* state) {
    const char* operation = luaL_checkstring(state, 1);
    size_t length = 0;
    const char* payload = luaL_checklstring(state, 2, &length);
    const bool hasCallback = !lua_isnoneornil(state, 3);
    if (hasCallback) {
        luaL_checktype(state, 3, LUA_TFUNCTION);
    }
    const char* error = !available ? "bridge_unavailable" : length > kMaxPayload ? "payload_too_large" : 0;
    if (!error) {
        const uint64_t id = ++nextId;
        const bool isActivation = std::strcmp(operation, "activate") == 0;
        const bool isRequest = std::strcmp(operation, "startup") == 0 || std::strcmp(operation, "deferred") == 0;
        const auto deadline = isRequest
            ? Inbox::Clock::now() + std::chrono::seconds(kStartupTimeoutSeconds)
            : Inbox::Clock::time_point::max();
        error = inbox->Reserve(id, deadline, isActivation);
        if (!error) {
            if (hasCallback) {
                callbacks.emplace(id, dmScript::CreateCallback(state, 3));
            }
            if (Submit(id, operation, payload, length)) {
                lua_pushboolean(state, 1);
                return 1;
            }
            const auto callback = callbacks.find(id);
            if (callback != callbacks.end()) {
                dmScript::DestroyCallback(callback->second);
                callbacks.erase(callback);
            }
            inbox->Remove(id);
            error = "queue_full";
        }
    }
    lua_pushnil(state);
    lua_pushstring(state, error);
    return 2;
}

/// Доставляет один ответ Lua с восстановлением контекста скрипта Defold.
static void Deliver(uint64_t id, const Inbox::Result& result) {
    const auto entry = callbacks.find(id);
    if (entry == callbacks.end()) {
        if (!result.code.empty()) {
            dmLogWarning("AppMetrica: %s", result.code.c_str());
        }
        return;
    }
    auto* callback = entry->second;
    callbacks.erase(entry);
    if (dmScript::IsCallbackValid(callback) && dmScript::SetupCallback(callback)) {
        lua_State* state = dmScript::GetCallbackLuaContext(callback);
        lua_pushstring(state, result.code.c_str());
        lua_pushlstring(state, result.payload.data(), result.payload.size());
        dmScript::PCall(state, 3, 0);
        dmScript::TeardownCallback(callback);
    }
    dmScript::DestroyCallback(callback);
}

/// Подключает платформенный мост и регистрирует внутренний Lua-модуль.
static dmExtension::Result Initialize(dmExtension::Params* params) {
    available = InitializePlatform();
    const luaL_reg functions[] = {{"enqueue", Enqueue}, {0, 0}};
    luaL_register(params->m_L, "appmetrica_native", functions);
    lua_pushboolean(params->m_L, available);
    lua_setfield(params->m_L, -2, "available");
    lua_pop(params->m_L, 1);
    return dmExtension::RESULT_OK;
}

/// Забирает ограниченное число ответов за кадр в игровом потоке.
static dmExtension::Result Update(dmExtension::Params*) {
    for (unsigned count = 0; count < kMaxCompletionsPerFrame; ++count) {
        uint64_t id = 0;
        Inbox::Result result;
        if (!inbox->Take(Inbox::Clock::now(), id, result)) {
            break;
        }
        Deliver(id, result);
    }
    return dmExtension::RESULT_OK;
}

/// Отменяет доставку старых ответов и освобождает Lua-ссылки.
static dmExtension::Result Finalize(dmExtension::Params*) {
    available = false;
    inbox->Clear();
    for (const auto& entry : callbacks) {
        dmScript::DestroyCallback(entry.second);
    }
    callbacks.clear();
    FinalizePlatform();
    return dmExtension::RESULT_OK;
}

#else

/// Оставляет Lua-обёртке возможность сообщить об отсутствии поддержки платформы.
static dmExtension::Result Initialize(dmExtension::Params*) {
    return dmExtension::RESULT_OK;
}

/// Сохраняет одинаковый контракт расширения на настольных платформах и HTML5.
static dmExtension::Result Update(dmExtension::Params*) {
    return dmExtension::RESULT_OK;
}

/// Завершает пустой адаптер неподдерживаемой платформы.
static dmExtension::Result Finalize(dmExtension::Params*) {
    return dmExtension::RESULT_OK;
}

#endif

}

DM_DECLARE_EXTENSION(MobileAppMetrica, "MobileAppMetrica", 0, 0,
                     appmetrica::Initialize, appmetrica::Update, 0, appmetrica::Finalize)
