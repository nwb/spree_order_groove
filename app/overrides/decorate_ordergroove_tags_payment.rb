Deface::Override.new(
    :virtual_path => "spree/checkout/_payment",
    :name => "ordergroove_tags_payment",
    :insert_after => "[data-hook='outside_cart_form']",
    :partial => "spree/shared/ordergroove_tags",
    :disabled => false)
