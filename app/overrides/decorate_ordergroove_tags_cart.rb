Deface::Override.new(
    :virtual_path => "spree/orders/edit",
    :name => "ordergroove_tags_cart",
    :insert_after => "[data-hook='cart_container']",
    :partial => "spree/shared/ordergroove_tags",
    :disabled => false)
