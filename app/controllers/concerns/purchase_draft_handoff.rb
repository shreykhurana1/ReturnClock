module PurchaseDraftHandoff
  extend ActiveSupport::Concern

  PURCHASE_DRAFT_FIELDS = %w[item_name price purchase_date status store_policy_id].freeze

  private

  def save_purchase_draft(purchase: nil)
    attributes = params.expect(purchase: PURCHASE_DRAFT_FIELDS).to_h
    # Keep the encrypted session cookie comfortably below its size limit.
    raise ActionController::BadRequest, "Purchase draft is too large" if attributes.to_json.bytesize > 1800

    token = SecureRandom.hex(16)
    session[:purchase_draft] = {
      "token" => token, "session_id" => Current.session.id,
      "expires_at" => 30.minutes.from_now.to_i, "attributes" => attributes,
      "purchase_id" => purchase&.id
    }
    token
  end

  def current_purchase_draft
    draft = session[:purchase_draft]
    return unless draft

    if draft["session_id"] != Current.session.id || draft["expires_at"] <= Time.current.to_i
      session.delete(:purchase_draft)
      return
    end
    return unless params[:draft].is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(draft["token"], params[:draft])

    draft
  end

  def consume_purchase_draft(purchase: nil)
    draft = current_purchase_draft
    return {} unless draft

    # A valid token must never populate a different purchase (or a new purchase).
    raise ActiveRecord::RecordNotFound unless draft["purchase_id"] == purchase&.id

    session.delete(:purchase_draft)
    draft["attributes"].slice(*PURCHASE_DRAFT_FIELDS)
  end
end
