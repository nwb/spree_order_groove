Deface::Override.new(
    :virtual_path => "spree/orders/_line_item",
    :name => "ordergroove_div_cart",
    :replace => "[data-hook='line_item_description']",
    :partial => "spree/shared/ordergroove_line_item_div",
    :disabled => false)
