Deface::Override.new(
  virtual_path: 'spree/admin/users/edit',
  name: 'add_subscriptions_to_admin_users_account',
  insert_after: '[data-hook="admin_user_api_key"]',
  partial: 'spree/users/subscriptions'
)
