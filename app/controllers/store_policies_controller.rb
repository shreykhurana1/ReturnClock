class StorePoliciesController < ApplicationController
  before_action :set_store_policy, only: [ :edit, :update, :destroy ]
  before_action :set_creation_context, only: [ :new, :create ]

  def index
    @store_policies = Current.user.store_policies.order(:store_name, :id)
  end

  def new
    @store_policy = Current.user.store_policies.new
  end

  def create
    @store_policy = Current.user.store_policies.new(store_policy_params)

    if @store_policy.save
      destination = @from_purchase ? new_purchase_path(store_policy_id: @store_policy.id, sample: params[:sample].presence) : store_policies_path
      redirect_to destination, notice: "Store return policy created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @store_policy.update(store_policy_params)
      redirect_to store_policies_path, notice: "Store policy updated. Existing purchase deadlines are unchanged.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @store_policy.destroy
      redirect_to store_policies_path, notice: "Store policy deleted.", status: :see_other
    else
      redirect_to store_policies_path, alert: @store_policy.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def set_creation_context
    @from_purchase = params[:origin] == "purchase"
  end

  def set_store_policy
    @store_policy = Current.user.store_policies.find(params[:id])
  end

  def store_policy_params
    params.expect(store_policy: [ :store_name, :window_days ])
  end
end
