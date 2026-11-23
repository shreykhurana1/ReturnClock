module PurchaseDraftHandoff
  extend ActiveSupport::Concern

  PURCHASE_DRAFT_FIELDS = %w[item_name price purchase_date status store_policy_id].freeze

  private

  def save_purchase_draft
    attributes = params.expect(purchase: PURCHASE_DRAFT_FIELDS).to_h
    # Keep the encrypted session cookie comfortably below its size limit.
    raise ActionController::BadRequest, "Purchase draft is too large" if attributes.to_json.bytesize > 1800

    token = SecureRandom.hex(16)
    session[:purchase_draft] = {
      "token" => token, "session_id" => Current.session.id,
      "expires_at" => 30.minutes.from_now.to_i, "attributes" => attributes
    }
    token
  end

  def consume_purchase_draft
    draft = session[:purchase_draft]
    return {} unless draft

    if draft["session_id"] != Current.session.id || draft["expires_at"] <= Time.current.to_i
      session.delete(:purchase_draft)
      return {}
    end
    return {} unless params[:draft].is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(draft["token"], params[:draft])

    session.delete(:purchase_draft)
    draft["attributes"].slice(*PURCHASE_DRAFT_FIELDS)
  end
end
