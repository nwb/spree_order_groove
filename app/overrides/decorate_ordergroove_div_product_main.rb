Deface::Override.new(
    :virtual_path => "spree/products/_cart_form",
    :name => "ordergroove_div_product_main",
    :insert_before => "[data-hook='product_price']",
    :text => '<div id="og-div_main"></div>',
    :disabled => false)
