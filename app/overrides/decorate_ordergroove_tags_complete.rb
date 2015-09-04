Deface::Override.new(
    :virtual_path => "spree/orders/show",
    :name => "ordergroove_tags_payment",
    :insert_after => "div[data-hook='links']",
    :partial => "spree/shared/ordergroove_tags",
    :disabled => false)
