class PurchasesController < ApplicationController
  def new
    @store_policies = Current.user.store_policies.order(:store_name, :id)
    @purchase = Current.user.purchases.new(purchase_date: Date.current)
    @purchase.store_policy = @store_policies.find_by(id: params[:store_policy_id])
  end

  def create
    attributes = purchase_params
    @purchase = Current.user.purchases.new(attributes.except(:store_policy_id))
    # Resolve the policy through its owner before associating it with the purchase.
    @purchase.store_policy = Current.user.store_policies.find_by(id: attributes[:store_policy_id])

    if @purchase.save
      redirect_to dashboard_path, notice: "Purchase added."
    else
      @store_policies = Current.user.store_policies.order(:store_name, :id)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def purchase_params
    params.expect(purchase: [ :item_name, :price, :purchase_date, :store_policy_id ])
  end
end
