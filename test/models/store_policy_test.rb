require "test_helper"

class StorePolicyTest < ActiveSupport::TestCase
  test "store policies are valid for separate owners" do
    %w[one two].each do |name|
      user = User.create!(email_address: "#{name}@example.com", password: "Password1!")
      policy = user.store_policies.create!(store_name: "Campus Store", window_days: 1)

      assert policy.reload.valid?, policy.errors.full_messages.to_sentence
      assert_equal user, policy.user
    end
  end
end
