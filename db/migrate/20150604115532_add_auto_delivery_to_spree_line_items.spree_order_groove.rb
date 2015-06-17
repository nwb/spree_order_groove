class AddAutoDeliveryToSpreeLineItems < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :auto_delivery, :boolean, :default => false
  end
end