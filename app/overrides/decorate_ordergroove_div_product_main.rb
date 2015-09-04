Deface::Override.new(
    :virtual_path => "spree/products/_cart_form",
    :name => "ordergroove_div_product_main",
    :insert_before => "[data-hook='inside_product_cart_form']",
    :text => '<div id="og-div_main"></div>',
    :disabled => false)
