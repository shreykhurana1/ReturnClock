require "test_helper"

class PurchaseTest < ActiveSupport::TestCase
  test "purchases are valid and have consistent initial deadlines" do
    %w[one two].each do |name|
      user = User.create!(email_address: "#{name}@example.com", password: "Password1!")
      policy = user.store_policies.create!(store_name: "Campus Store", window_days: 1)
      purchase = user.purchases.create!(store_policy: policy, item_name: "Textbook", price: "9.99", purchase_date: Date.new(2026, 10, 28))

      assert purchase.reload.valid?, purchase.errors.full_messages.to_sentence
      assert_equal user, purchase.user
      assert_equal policy, purchase.store_policy
      assert_equal purchase.purchase_date + purchase.store_policy.window_days, purchase.return_by
    end
  end
end
