module ApplicationHelper
  # 1. Enable previews only while one or more purchase CRUD routes are missing.
  def purchase_preview_enabled?
    %i[new_purchase_path edit_purchase_path purchase_path].any? { |route| !respond_to?(route) }
  end

  def sample_purchases(history: false)
    items = if history
      [ [ "bluetooth_speaker", "refunded", -1, "25.00" ],
        [ "travel_mug", "keeping", -1, "25.00" ],
        [ "wireless_mouse", "active", -1, "25.00" ] ]
    else
      [ [ "wireless_headphones", "active", 0, "19.99" ],
        [ "mechanical_keyboard", "active", 1, "20.99" ],
        [ "usb_c_charger", "active", 2, "21.99" ],
        [ "laptop_stand", "active", 3, "22.99" ],
        [ "everyday_backpack", "active", 4, "23.99" ],
        [ "desk_lamp", "active", 5, "24.99" ],
        [ "running_shoes", "active", 6, "25.99" ] ]
    end
    policy = StorePolicy.new(store_name: t("ui.sample_store"), window_days: 30)
    items.map do |name, status, days, price|
      Purchase.new(item_name: t("ui.sample_items.#{name}"), status: status, price: price, store_policy: policy,
        purchase_date: Date.current + days - 30, return_by: Date.current + days)
    end
  end

  def purchase_status_options
    Purchase::STATUSES.map { |state| [ state.titleize, state ] }
  end

  def localized_flash(message)
    t("ui.flash").fetch(message.to_s.to_sym, message)
  end

  def signup_password_errors(user, attribute)
    user.errors.where(attribute).map do |error|
      if error.type.is_a?(String)
        t("ui.password_strength")
      else
        error.message
      end
    end
  end
end
