package com.defold.extension.qb.appmetrica;

import io.appmetrica.analytics.ecommerce.ECommerceAmount;
import io.appmetrica.analytics.ecommerce.ECommerceCartItem;
import io.appmetrica.analytics.ecommerce.ECommerceEvent;
import io.appmetrica.analytics.ecommerce.ECommerceOrder;
import io.appmetrica.analytics.ecommerce.ECommercePrice;
import io.appmetrica.analytics.ecommerce.ECommerceProduct;
import io.appmetrica.analytics.ecommerce.ECommerceReferrer;
import io.appmetrica.analytics.ecommerce.ECommerceScreen;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/** Преобразует проверенные Lua-модели электронной коммерции в типы Android SDK. */
final class Commerce {
    /** Создаёт событие SDK по типу и вложенным данным. */
    static ECommerceEvent event(JSONObject value) throws JSONException {
        switch (value.getString("type")) {
            case "show_screen":
                return ECommerceEvent.showScreenEvent(screen(value.getJSONObject("screen")));
            case "show_product_card":
                return ECommerceEvent.showProductCardEvent(product(value.getJSONObject("product")),
                    screen(value.getJSONObject("screen")));
            case "show_product_details":
                return ECommerceEvent.showProductDetailsEvent(product(value.getJSONObject("product")),
                    referrer(value.optJSONObject("referrer")));
            case "add_cart_item":
                return ECommerceEvent.addCartItemEvent(item(value.getJSONObject("item")));
            case "remove_cart_item":
                return ECommerceEvent.removeCartItemEvent(item(value.getJSONObject("item")));
            case "begin_checkout":
                return ECommerceEvent.beginCheckoutEvent(order(value.getJSONObject("order")));
            case "purchase":
                return ECommerceEvent.purchaseEvent(order(value.getJSONObject("order")));
            default:
                throw new IllegalArgumentException("Неизвестный тип события электронной коммерции");
        }
    }

    /** Создаёт экран либо возвращает null для отсутствующего экрана реферера. */
    private static ECommerceScreen screen(JSONObject value) throws JSONException {
        if (value == null) return null;
        ECommerceScreen screen = new ECommerceScreen();
        if (value.has("name")) screen.setName(value.getString("name"));
        if (value.has("search_query")) screen.setSearchQuery(value.getString("search_query"));
        if (value.has("categories")) screen.setCategoriesPath(strings(value.getJSONArray("categories")));
        if (value.has("payload")) screen.setPayload(fields(value.getJSONObject("payload")));
        return screen;
    }

    /** Создаёт источник перехода либо возвращает null, если он отсутствует. */
    private static ECommerceReferrer referrer(JSONObject value) throws JSONException {
        if (value == null) return null;
        ECommerceReferrer referrer = new ECommerceReferrer();
        if (value.has("type")) referrer.setType(value.getString("type"));
        if (value.has("identifier")) referrer.setIdentifier(value.getString("identifier"));
        if (value.has("screen")) referrer.setScreen(screen(value.getJSONObject("screen")));
        return referrer;
    }

    /** Создаёт цену в валюте и необязательные компоненты во внутренних единицах. */
    private static ECommercePrice price(JSONObject value) throws JSONException {
        ECommercePrice price = new ECommercePrice(new ECommerceAmount(
            new BigDecimal(value.getString("amount")), value.getString("currency")));
        JSONArray components = value.optJSONArray("components");
        if (components != null) {
            List<ECommerceAmount> values = new ArrayList<>();
            for (int index = 0; index < components.length(); ++index) {
                JSONObject component = components.getJSONObject(index);
                values.add(new ECommerceAmount(
                    new BigDecimal(component.getString("amount")), component.getString("unit")));
            }
            price.setInternalComponents(values);
        }
        return price;
    }

    /** Создаёт товар по SKU, ценам и необязательным данным. */
    private static ECommerceProduct product(JSONObject value) throws JSONException {
        ECommerceProduct product = new ECommerceProduct(value.getString("sku"));
        if (value.has("name")) product.setName(value.getString("name"));
        if (value.has("categories")) product.setCategoriesPath(strings(value.getJSONArray("categories")));
        if (value.has("promo_codes")) product.setPromocodes(strings(value.getJSONArray("promo_codes")));
        if (value.has("payload")) product.setPayload(fields(value.getJSONObject("payload")));
        if (value.has("actual_price")) product.setActualPrice(price(value.getJSONObject("actual_price")));
        if (value.has("original_price")) product.setOriginalPrice(price(value.getJSONObject("original_price")));
        return product;
    }

    /** Создаёт позицию корзины с товаром, полной ценой и целым количеством. */
    private static ECommerceCartItem item(JSONObject value) throws JSONException {
        ECommerceCartItem item = new ECommerceCartItem(product(value.getJSONObject("product")),
            price(value.getJSONObject("revenue")), (double) value.getInt("quantity"));
        if (value.has("referrer")) item.setReferrer(referrer(value.getJSONObject("referrer")));
        return item;
    }

    /** Создаёт заказ с позициями корзины и необязательными параметрами. */
    private static ECommerceOrder order(JSONObject value) throws JSONException {
        JSONArray items = value.getJSONArray("items");
        List<ECommerceCartItem> cart = new ArrayList<>();
        for (int index = 0; index < items.length(); ++index) {
            cart.add(item(items.getJSONObject(index)));
        }
        ECommerceOrder order = new ECommerceOrder(value.getString("id"), cart);
        if (value.has("payload")) order.setPayload(fields(value.getJSONObject("payload")));
        return order;
    }

    /** Копирует строки из JSON-массива в список SDK. */
    private static List<String> strings(JSONArray value) throws JSONException {
        List<String> result = new ArrayList<>();
        for (int index = 0; index < value.length(); ++index) {
            result.add(value.getString(index));
        }
        return result;
    }

    /** Копирует строковые поля JSON-объекта в карту SDK. */
    static Map<String, String> fields(JSONObject value) throws JSONException {
        Map<String, String> result = new HashMap<>();
        Iterator<String> keys = value.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            result.put(key, value.getString(key));
        }
        return result;
    }
}
