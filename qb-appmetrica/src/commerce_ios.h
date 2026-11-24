#pragma once

#import <AppMetricaCore/AppMetricaCore.h>

namespace appmetrica {

/// Преобразует проверенную Lua-модель электронной коммерции в событие iOS SDK.
AMAECommerce* CommerceEvent(NSDictionary* event);

}
