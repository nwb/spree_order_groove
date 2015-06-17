Deface::Override.new(
    :virtual_path => "spree/orders/_line_item",
    :name => "ordergroove_div_cart_remove",
    :replace => "[data-hook='cart_item_delete']",
    :partial => "spree/shared/ordergroove_line_item_div_remove",
    :disabled => false)
