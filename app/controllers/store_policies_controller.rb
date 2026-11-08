class StorePoliciesController < ApplicationController
  def new
    @store_policy = Current.user.store_policies.new
  end

  def create
    @store_policy = Current.user.store_policies.new(store_policy_params)

    if @store_policy.save
      redirect_to new_purchase_path(store_policy_id: @store_policy.id), notice: "Store return policy created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def store_policy_params
    params.expect(store_policy: [ :store_name, :window_days ])
  end
end
