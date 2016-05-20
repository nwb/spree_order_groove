Deface::Override.new(
    :virtual_path => "spree/users/show",
    :name => "ordergroove_tags_account",
    :insert_after => "[data-hook='account_my_auto_delivery']",
    :partial => "spree/shared/ordergroove_account_tags",
    :disabled => false)