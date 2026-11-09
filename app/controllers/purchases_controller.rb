class PurchasesController < ApplicationController
  before_action :set_purchase, only: [ :edit, :update, :confirm_delete, :destroy ]
  before_action :set_sample_purchase, only: [ :new, :create ]

  def new
    @store_policies = Current.user.store_policies.order(:store_name, :id)
    @purchase = Current.user.purchases.new(purchase_date: Date.current)
    @purchase.store_policy = @store_policies.find_by(id: params[:store_policy_id])
    if @sample_purchase
      @purchase.assign_attributes(@sample_purchase.attributes.slice("item_name", "price", "purchase_date"))
      @purchase.store_policy ||= @store_policies.find_by(store_name: @sample_purchase.store_policy.store_name)
    end
  end

  def create
    attributes = purchase_params
    @purchase = Current.user.purchases.new(attributes.except(:store_policy_id))
    # Resolve the policy through its owner before associating it with the purchase.
    @purchase.store_policy = Current.user.store_policies.find_by(id: attributes[:store_policy_id])

    if @purchase.save
      redirect_to purchase_page, notice: "Purchase added."
    else
      @store_policies = Current.user.store_policies.order(:store_name, :id)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @store_policies = Current.user.store_policies.order(:store_name, :id)
  end

  def update
    attributes = params.expect(purchase: [ :item_name, :price, :purchase_date, :store_policy_id, :status ])
    @purchase.assign_attributes(attributes.except(:store_policy_id))
    if attributes.key?(:store_policy_id)
      @purchase.store_policy = Current.user.store_policies.find_by(id: attributes[:store_policy_id])
    end

    if @purchase.save
      redirect_to purchase_page, notice: "Purchase updated.", status: :see_other
    else
      @store_policies = Current.user.store_policies.order(:store_name, :id)
      render :edit, status: :unprocessable_entity
    end
  end

  def confirm_delete
    @cancel_path = purchase_page
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

  def purchase_page
    if %w[keeping refunded].include?(@purchase.status) ||
        (@purchase.status == "active" && @purchase.return_by < Date.current)
      history_path
    else
      dashboard_path
    end
  end

  def purchase_params
    params.expect(purchase: [ :item_name, :price, :purchase_date, :store_policy_id, :status ])
  end
end
