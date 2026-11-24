#if defined(DM_PLATFORM_IOS)

#import "commerce_ios.h"

namespace appmetrica {

/// Создаёт экран или возвращает nil для отсутствующего экрана реферера.
static AMAECommerceScreen* Screen(NSDictionary* value) {
    if (!value) return nil;
    return [[AMAECommerceScreen alloc] initWithName:value[@"name"] categoryComponents:value[@"categories"]
        searchQuery:value[@"search_query"] payload:value[@"payload"]];
}

/// Создаёт источник перехода или возвращает nil, если он отсутствует.
static AMAECommerceReferrer* Referrer(NSDictionary* value) {
    if (!value) return nil;
    return [[AMAECommerceReferrer alloc] initWithType:value[@"type"] identifier:value[@"identifier"]
        screen:Screen(value[@"screen"])];
}

/// Создаёт сумму в валюте или внутренней единице с десятичной точностью.
static AMAECommerceAmount* Amount(NSString* unit, NSString* value) {
    NSDecimalNumber* amount = [NSDecimalNumber decimalNumberWithString:value
                                                               locale:@{NSLocaleDecimalSeparator: @"."}];
    return [[AMAECommerceAmount alloc] initWithUnit:unit value:amount];
}

/// Создаёт цену и её необязательные компоненты во внутренних единицах.
static AMAECommercePrice* Price(NSDictionary* value) {
    if (!value) return nil;
    NSMutableArray<AMAECommerceAmount*>* components = [NSMutableArray array];
    for (NSDictionary* component in value[@"components"]) {
        [components addObject:Amount(component[@"unit"], component[@"amount"])];
    }
    return [[AMAECommercePrice alloc] initWithFiat:Amount(value[@"currency"], value[@"amount"])
        internalComponents:components];
}

/// Создаёт товар с SKU, ценами и дополнительными полями.
static AMAECommerceProduct* Product(NSDictionary* value) {
    return [[AMAECommerceProduct alloc] initWithSKU:value[@"sku"] name:value[@"name"]
        categoryComponents:value[@"categories"] payload:value[@"payload"] actualPrice:Price(value[@"actual_price"])
        originalPrice:Price(value[@"original_price"]) promoCodes:value[@"promo_codes"]];
}

/// Создаёт позицию корзины с товаром, полной ценой и целым количеством.
static AMAECommerceCartItem* Item(NSDictionary* value) {
    NSDecimalNumber* quantity = [NSDecimalNumber decimalNumberWithDecimal:[value[@"quantity"] decimalValue]];
    return [[AMAECommerceCartItem alloc] initWithProduct:Product(value[@"product"]) quantity:quantity
        revenue:Price(value[@"revenue"]) referrer:Referrer(value[@"referrer"])];
}

/// Создаёт заказ, сохраняя порядок позиций корзины.
static AMAECommerceOrder* Order(NSDictionary* value) {
    NSMutableArray<AMAECommerceCartItem*>* items = [NSMutableArray array];
    for (NSDictionary* item in value[@"items"]) {
        [items addObject:Item(item)];
    }
    return [[AMAECommerceOrder alloc] initWithIdentifier:value[@"id"] cartItems:items payload:value[@"payload"]];
}

AMAECommerce* CommerceEvent(NSDictionary* event) {
    NSString* type = event[@"type"];
    if ([type isEqualToString:@"show_screen"]) {
        return [AMAECommerce showScreenEventWithScreen:Screen(event[@"screen"])];
    }
    if ([type isEqualToString:@"show_product_card"]) {
        return [AMAECommerce showProductCardEventWithProduct:Product(event[@"product"]) screen:Screen(event[@"screen"])];
    }
    if ([type isEqualToString:@"show_product_details"]) {
        return [AMAECommerce showProductDetailsEventWithProduct:Product(event[@"product"])
            referrer:Referrer(event[@"referrer"])];
    }
    if ([type isEqualToString:@"add_cart_item"]) return [AMAECommerce addCartItemEventWithItem:Item(event[@"item"])];
    if ([type isEqualToString:@"remove_cart_item"]) return [AMAECommerce removeCartItemEventWithItem:Item(event[@"item"])];
    if ([type isEqualToString:@"begin_checkout"]) return [AMAECommerce beginCheckoutEventWithOrder:Order(event[@"order"])];
    if ([type isEqualToString:@"purchase"]) return [AMAECommerce purchaseEventWithOrder:Order(event[@"order"])];
    return nil;
}

}

#endif
