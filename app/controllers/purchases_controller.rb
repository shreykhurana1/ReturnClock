class PurchasesController < ApplicationController
  before_action :set_purchase, only: [ :edit, :update, :confirm_delete, :destroy ]
  before_action :set_sample_purchase, only: [ :new, :create ]

  def new
    @purchase = Current.user.purchases.new(purchase_date: Date.current)
    if @sample_purchase
      @purchase.assign_attributes(@sample_purchase.attributes.slice("item_name", "price", "purchase_date"))
    end
  end

  def create
    @purchase = Current.user.purchases.new(purchase_params)

    if @purchase.save
      offer_to_save_store
      redirect_to purchase_page, notice: created_notice
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @purchase.assign_attributes(purchase_params)

    if @purchase.save
      offer_to_save_store
      redirect_to purchase_page, notice: "Purchase updated.", status: :see_other
    elsif params[:quick].present?
      # Status changes from a card go back to that card's page with the reason.
      alert = @purchase.errors.full_messages.to_sentence
      @purchase.restore_attributes
      redirect_to purchase_page, alert: alert, status: :see_other
    else
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
    @purchase.on_dashboard? ? dashboard_path : history_path
  end

  def created_notice
    if @purchase.status == "expired"
      %(The return-by date has passed, so "#{@purchase.item_name}" was logged as expired.)
    else
      "Purchase added."
    end
  end

  # Offers to remember a store's window the first time it is used.
  def offer_to_save_store
    return unless @purchase.store_name && @purchase.return_window_days&.positive?
    return if @purchase.matching_store_policy

    flash[:save_store] = { "store_name" => @purchase.store_name, "window_days" => @purchase.return_window_days }
  end

  def purchase_params
    params.expect(purchase: [ :item_name, :store_name, :price, :purchase_date, :return_window_days, :return_by, :status ])
  end
end
