Deface::Override.new(
    :virtual_path => "spree/checkout/_address",
    :name => "ordergroove_password_address",
    :insert_after => "[data-hook='shipping_fieldset_email']",
    :partial => "spree/shared/ordergroove_address_password",
    :disabled => false)
