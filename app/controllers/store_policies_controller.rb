class StorePoliciesController < ApplicationController
  include PurchaseDraftHandoff

  layout "application"

  before_action :set_store_policy, only: [ :edit, :update, :destroy ]
  before_action :set_creation_context, only: [ :new, :create ]
  rescue_from ActiveRecord::RecordNotUnique, with: :duplicate_policy

  def index
    @store_policies = Current.user.store_policies.order(:store_name, :window_days, :id)
  end

  def new
    @store_policy = Current.user.store_policies.new
  end

  def from_purchase
    @purchase = Current.user.purchases.find(params[:purchase_id]) if params[:purchase_id].present?
    @purchase_draft_token = save_purchase_draft(purchase: @purchase)
    @from_purchase = true
    @store_policy = Current.user.store_policies.new
    set_purchase_return_context
    # Render directly so Turbo keeps this handoff inside the existing editor frame.
    render :new
  end

  def create
    @store_policy = Current.user.store_policies.new(store_policy_params)

    if @store_policy.save
      destination = if @from_purchase
        purchase_return_path(store_policy_id: @store_policy.id, sample: params[:sample].presence, draft: @purchase_draft_token)
      else
        store_policies_path
      end
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

  # The database also catches duplicates when two valid submissions race.
  def duplicate_policy
    @store_policy.errors.add(:store_name, "already has a policy with that return window")
    render @store_policy.persisted? ? :edit : :new, status: :unprocessable_entity
  end

  def set_creation_context
    @from_purchase = params[:origin] == "purchase"
    return unless @from_purchase

    @purchase_draft_token = params[:draft].presence
    draft = current_purchase_draft if @purchase_draft_token.present?
    @purchase = Current.user.purchases.find_by(id: draft&.dig("purchase_id"))
    set_purchase_return_context
  end

  def set_purchase_return_context
    @purchase_return_label = @purchase ? "Back to Edit Purchase" : "Back to Add Purchase"
    @purchase_return_path = purchase_return_path(draft: @purchase_draft_token, sample: params[:sample].presence)
  end

  def purchase_return_path(draft: nil, store_policy_id: nil, sample: nil)
    options = { draft: draft, store_policy_id: store_policy_id, sample: sample }.compact
    @purchase ? edit_purchase_path(@purchase, **options) : new_purchase_path(**options)
  end

  def set_store_policy
    @store_policy = Current.user.store_policies.find(params[:id])
  end

  def store_policy_params
    params.expect(store_policy: [ :store_name, :window_days ])
  end
end
