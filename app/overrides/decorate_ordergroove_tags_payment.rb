Deface::Override.new(
    :virtual_path => "spree/checkout/edit",
    :name => "ordergroove_tags_payment",
    :insert_after => "[data-hook='checkout_header']",
    :partial => "spree/shared/ordergroove_tags",
    :disabled => false)
