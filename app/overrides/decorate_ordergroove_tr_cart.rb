Deface::Override.new(
    :virtual_path => "spree/orders/_line_item",
    :name => "ordergroove_tr_cart",
    :insert_after => "[data-hook='cart_item_row']",
    :partial => "spree/shared/ordergroove_line_item_tr",
    :disabled => false)
