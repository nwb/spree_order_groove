class AddFrequencyToSpreeLineItems < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :frequency, :string
  end
end