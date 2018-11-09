class Spree::SubscriptionNotifier < ApplicationMailer

  default from: "spree-commerce@example.com"

  def notify_confirmation(subscription)
    @subscription = subscription
    
    store=@subscription.parent_order.store
    email=@subscription.user.email
    store_code=store.code

    bronto_config=Spree::BrontoConfiguration.new

    message_name = bronto_config.account[store.code]["subscription_received"]
    token= bronto_config.account[store_code]['token']
    from_email= bronto_config.account[store_code]['from_address']
    from_name= bronto_config.account[store_code]['from_name']
    reply_email= bronto_config.account[store_code]['from_address']
    email_options={:fromEmail =>from_email,:fromName => from_name, :replyEmail => reply_email}


    view = ActionView::Base.new(Rails::Application::Configuration.new(Rails.root).paths["app/mailers/spree"])
    view.view_paths<<File.join(File.dirname(__FILE__), '.')

    attributes = {:First_Name => @subscription.bill_address.firstname,
                  :Last_name => @subscription.bill_address.lastname}

    attributes[:SENDTIME__CONTENT1] = ""
    attributes[:SENDTIME__CONTENT2] = (view.render("subscription_mailer/subscription_confirm_html", :subscription => @subscription)).gsub(/\n/,'').html_safe

    begin
      communication = BrontoIntegration::Communication.new(token)
      communication.trigger_delivery_by_id(message_name,email,'transactional','html',attributes,email_options)

    rescue => exception
      raise exception unless exception.to_s.include? 'Error Code: 303'
      #end
    end
    
  end

  def notify_cancellation(subscription)
    @subscription = subscription

    store=@subscription.parent_order.store
    email=@subscription.user.email
    store_code=store.code

    bronto_config=Spree::BrontoConfiguration.new

    message_name = bronto_config.account[store.code]["subscription_canceled"]
    token= bronto_config.account[store_code]['token']
    from_email= bronto_config.account[store_code]['from_address']
    from_name= bronto_config.account[store_code]['from_name']
    reply_email= bronto_config.account[store_code]['from_address']
    email_options={:fromEmail =>from_email,:fromName => from_name, :replyEmail => reply_email}


    view = ActionView::Base.new(Rails::Application::Configuration.new(Rails.root).paths["app/mailers/spree"])
    view.view_paths<<File.join(File.dirname(__FILE__), '.')

    attributes = {:First_Name => @subscription.bill_address.firstname,
                  :Last_name => @subscription.bill_address.lastname}

    attributes[:SENDTIME__CONTENT1] = ""
    attributes[:SENDTIME__CONTENT2] = (view.render("subscription_mailer/subscription_cancel_html", :subscription => @subscription)).gsub(/\n/,'').html_safe

    begin
      communication = BrontoIntegration::Communication.new(token)
      communication.trigger_delivery_by_id(message_name,email,'transactional','html',attributes,email_options)

    rescue => exception
      raise exception unless exception.to_s.include? 'Error Code: 303'
      #end
    end
  end

  # not in use yet
  def notify_reoccurrence(subscription)
    @subscription = subscription

    store=@subscription.parent_order.store
    email=@subscription.user.email
    store_code=store.code

    bronto_config=Spree::BrontoConfiguration.new

    message_name = bronto_config.account[store.code]["order_received"]
    token= bronto_config.account[store_code]['token']
    from_email= bronto_config.account[store_code]['from_address']
    from_name= bronto_config.account[store_code]['from_name']
    reply_email= bronto_config.account[store_code]['from_address']
    email_options={:fromEmail =>from_email,:fromName => from_name, :replyEmail => reply_email}


    view = ActionView::Base.new(Rails::Application::Configuration.new(Rails.root).paths["app/mailers/spree"])
    view.view_paths<<File.join(File.dirname(__FILE__), '.')

    attributes = {:First_Name => @subscription.bill_address.firstname,
                  :Last_name => @subscription.bill_address.lastname}

    attributes[:SENDTIME__CONTENT1] = ""
    attributes[:SENDTIME__CONTENT2] = (view.render("subscription_mailer/subscription_reoccurrence_html", :subscription => @subscription)).gsub(/\n/,'').html_safe

    begin
      communication = BrontoIntegration::Communication.new(token)
      communication.trigger_delivery_by_id(message_name,email,'transactional','html',attributes,email_options)

    rescue => exception
      raise exception unless exception.to_s.include? 'Error Code: 303'
      #end
    end
  end

  def notify_for_next_delivery(subscription)

    @subscription = subscription

    store=@subscription.parent_order.store
    email=@subscription.user.email
    store_code=store.code

    bronto_config=Spree::BrontoConfiguration.new

    message_name = bronto_config.account[store.code]["subscription_notify"]
    token= bronto_config.account[store_code]['token']
    from_email= bronto_config.account[store_code]['from_address']
    from_name= bronto_config.account[store_code]['from_name']
    reply_email= bronto_config.account[store_code]['from_address']
    email_options={:fromEmail =>from_email,:fromName => from_name, :replyEmail => reply_email}


    view = ActionView::Base.new(Rails::Application::Configuration.new(Rails.root).paths["app/mailers/spree"])
    view.view_paths<<File.join(File.dirname(__FILE__), '.')

    attributes = {:First_Name => @subscription.bill_address.firstname,
                  :Last_name => @subscription.bill_address.lastname}

    attributes[:SENDTIME__CONTENT1] = ""
    attributes[:SENDTIME__CONTENT2] = (view.render("subscription_mailer/subscription_next_delivery_html", :subscription => @subscription)).gsub(/\n/,'').html_safe

    begin
      communication = BrontoIntegration::Communication.new(token)
      communication.trigger_delivery_by_id(message_name,email,'transactional','html',attributes,email_options)

    rescue => exception
      raise exception unless exception.to_s.include? 'Error Code: 303'
      #end
    end
  end

  def notify_for_cc_expiration(subscription)
    notify_subscriber(subscription, "subscription_cc_expiration", "subscription_cc_expiration")
  end

  def notify_for_oos(subscription)
    notify_subscriber(subscription, "subscription_oos", "subscription_oos")
  end

  def notify_for_placing_error(subscription)
    notify_subscriber(subscription, "subscription_placing_error", "subscription_placing_error")
  end

  def notify_for_unpaused(subscription)
    notify_subscriber(subscription, "subscription_unpaused", "subscription_cc_unpaused")
  end

  private
  
  def notify_subscriber(subscription, message_name, template)
    @subscription = subscription

    store=@subscription.parent_order.store
    email=@subscription.user.email
    store_code=store.code

    bronto_config=Spree::BrontoConfiguration.new

    message_name = bronto_config.account[store.code][message_name]
    token= bronto_config.account[store_code]['token']
    from_email= bronto_config.account[store_code]['from_address']
    from_name= bronto_config.account[store_code]['from_name']
    reply_email= bronto_config.account[store_code]['from_address']
    email_options={:fromEmail =>from_email,:fromName => from_name, :replyEmail => reply_email}


    view = ActionView::Base.new(Rails::Application::Configuration.new(Rails.root).paths["app/mailers/spree"])
    view.view_paths<<File.join(File.dirname(__FILE__), '.')

    attributes = {:First_Name => @subscription.bill_address.firstname,
                  :Last_name => @subscription.bill_address.lastname}

    attributes[:SENDTIME__CONTENT1] = ""
    attributes[:SENDTIME__CONTENT2] = (view.render("subscription_mailer/" + template, :subscription => @subscription)).gsub(/\n/,'').html_safe

    begin
      communication = BrontoIntegration::Communication.new(token)
      communication.trigger_delivery_by_id(message_name,email,'transactional','html',attributes,email_options)

    rescue => exception
      #raise exception unless exception.to_s.include? 'Error Code: 303'
      #end
    end

  end

end
