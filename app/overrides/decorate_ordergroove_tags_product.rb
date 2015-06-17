Deface::Override.new(
    :virtual_path => "spree/products/show",
    :name => "ordergroove_tags_product",
    :insert_after => "[data-hook='product_show']",
    :partial => "spree/shared/ordergroove_tags",
    :disabled => false)
