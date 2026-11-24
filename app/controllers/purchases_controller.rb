class PurchasesController < ApplicationController
  include PurchaseDraftHandoff

  before_action :set_purchase, only: [ :edit, :update, :confirm_delete, :destroy ]
  before_action :set_sample_purchase, only: [ :new, :create ]

  def new
    @store_policies = Current.user.store_policies.order(:store_name, :window_days, :id)
    @purchase = Current.user.purchases.new(purchase_date: Date.current)
    @purchase.store_policy = @store_policies.find_by(id: params[:store_policy_id])
    if @sample_purchase
      @purchase.assign_attributes(@sample_purchase.attributes.slice("item_name", "price", "purchase_date"))
      @purchase.store_policy ||= @store_policies.find_by(store_name: @sample_purchase.store_policy.store_name)
    end

    restore_purchase_draft
  end

  def create
    attributes = purchase_params
    @purchase = Current.user.purchases.new(attributes.except(:store_policy_id))
    # Resolve the policy through its owner before associating it with the purchase.
    @purchase.store_policy = Current.user.store_policies.find_by(id: attributes[:store_policy_id])

    if @purchase.save
      redirect_to purchase_page, notice: "Purchase added."
    else
      @store_policies = Current.user.store_policies.order(:store_name, :window_days, :id)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @store_policies = Current.user.store_policies.order(:store_name, :window_days, :id)
    @return_to = safe_local_path(params[:return_to]) || safe_referer_path
    restore_purchase_draft
  end

  def update
    attributes = params.expect(purchase: [ :item_name, :price, :purchase_date, :store_policy_id, :status ])
    @purchase.assign_attributes(attributes.except(:store_policy_id))
    if attributes.key?(:store_policy_id)
      @purchase.store_policy = Current.user.store_policies.find_by(id: attributes[:store_policy_id])
    end
    @return_to = safe_local_path(params[:return_to]) || safe_referer_path if params[:in_place].present?

    if @purchase.save
      if in_place_edit?
        render turbo_stream: in_place_edit_streams
      elsif quick_stream?
        render turbo_stream: quick_action_streams
      else
        redirect_to purchase_page, notice: "Purchase updated.", status: :see_other
      end
    elsif params[:quick].present?
      # Status changes from a card keep the card and page position.
      alert = @purchase.errors.full_messages.to_sentence
      @purchase.restore_attributes
      if quick_stream?
        render turbo_stream: turbo_stream.replace(helpers.dom_id(@purchase), partial: "shared/purchase_card",
          locals: { purchase: @purchase, alert: alert })
      else
        redirect_to purchase_page, alert: alert, status: :see_other
      end
    else
      @store_policies = Current.user.store_policies.order(:store_name, :window_days, :id)
      if in_place_edit?
        render :edit, formats: [ :html ], status: :unprocessable_entity
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def confirm_delete
    @cancel_path = safe_local_path(params[:return_to]) || purchase_page
    @return_to_editor = @cancel_path != purchase_page
  end

  def destroy
    destination = purchase_page
    @purchase.destroy!
    redirect_to destination, notice: "Purchase deleted.", status: :see_other
  end

  private

  def set_sample_purchase
    return if params[:sample].blank?

    @sample_purchase = (helpers.sample_purchases + helpers.sample_purchases(history: true))
      .find { |sample| sample.item_name == params[:sample] }
  end

  def set_purchase
    @purchase = Current.user.purchases.find(params[:id])
  end

  def safe_local_path(path)
    return unless path.is_a?(String)
    return unless path.start_with?("/") && !path.start_with?("//")

    path
  end

  def restore_purchase_draft
    draft = consume_purchase_draft
    @purchase_draft_restored = draft.any?
    return if draft.empty?

    @purchase.assign_attributes(draft.except("store_policy_id"))
    if params.key?(:store_policy_id)
      @purchase.store_policy = Current.user.store_policies.find_by(id: params[:store_policy_id])
    elsif (policy = Current.user.store_policies.find_by(id: draft["store_policy_id"]))
      @purchase.store_policy = policy
    end
  end

  def purchase_page
    if %w[keeping refunded].include?(@purchase.status) ||
        (@purchase.status == "active" && @purchase.return_by < Date.current)
      history_path
    else
      dashboard_path
    end
  end

  def quick_stream?
    params[:quick].present? && request.format.turbo_stream?
  end

  def quick_action_streams
    card = if %w[keeping refunded].include?(@purchase.status)
      turbo_stream.remove(helpers.dom_id(@purchase))
    else
      turbo_stream.replace(helpers.dom_id(@purchase), partial: "shared/purchase_card", locals: { purchase: @purchase })
    end

    [
      card,
      turbo_stream.replace("dashboard-stats", partial: "dashboard/stats",
        locals: { stats: DashboardStats.for(Current.user) }),
      turbo_stream.append("toast-container", partial: "shared/toast", locals: { message: quick_action_message })
    ]
  end

  def quick_action_message
    case @purchase.status
    when "keeping"
      "#{@purchase.item_name} moved to History."
    when "returning"
      "#{@purchase.item_name} marked as returning."
    when "shipped_back"
      "#{@purchase.item_name} marked as shipped back."
    when "refunded"
      "Refund received for #{@purchase.item_name}. Moved to History."
    else
      "Purchase updated."
    end
  end

  def in_place_edit?
    params[:in_place] == "1" && request.format.turbo_stream?
  end

  def in_place_edit_streams
    history_page = in_place_history_page?
    on_history = purchase_on_history_page?
    card = if history_page == on_history
      turbo_stream.replace(helpers.dom_id(@purchase), partial: "shared/purchase_card", locals: { purchase: @purchase })
    else
      turbo_stream.remove(helpers.dom_id(@purchase))
    end
    stats_partial = history_page ? "history/stats" : "dashboard/stats"
    stats_target = history_page ? "history-stats" : "dashboard-stats"
    stats = history_page ? HistoryStats.for(Current.user) : DashboardStats.for(Current.user)

    [
      card,
      turbo_stream.replace(stats_target, partial: stats_partial, locals: { stats: stats }),
      turbo_stream.append("toast-container", partial: "shared/toast",
        locals: { message: in_place_edit_message(history_page, on_history) })
    ]
  end

  def in_place_edit_message(history_page, on_history)
    if history_page == on_history
      "#{@purchase.item_name} updated."
    elsif on_history
      "#{@purchase.item_name} moved to History."
    else
      "#{@purchase.item_name} moved to Dashboard."
    end
  end

  def in_place_history_page?
    params[:return_to].to_s.start_with?("/history")
  end

  def purchase_on_history_page?
    %w[keeping refunded].include?(@purchase.status) ||
      (@purchase.status == "active" && @purchase.return_by < Date.current)
  end

  def safe_referer_path
    uri = URI.parse(request.referer.to_s)
    return unless uri.host == request.host

    safe_local_path(uri.request_uri)
  rescue URI::InvalidURIError
    nil
  end

  def purchase_params
    params.expect(purchase: [ :item_name, :price, :purchase_date, :store_policy_id, :status ])
  end
end
