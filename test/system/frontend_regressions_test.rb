require "application_system_test_case"

class FrontendRegressionsTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1400, 1000)
    @user = User.create!(email_address: "browser@example.com", password: "Password1!")
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "Password1!"
    click_button "Sign In"
    assert_selector "main h1", text: "Dashboard"
  end

  test "purchase modal preserves validation errors and save and deletion notices" do
    policy = @user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    click_link "Add Purchase", exact: true
    within("dialog[open]") do
      fill_in "Item Name", with: "Textbook"
      fill_in "Price", with: "49.99"
      fill_in "Purchase Date", with: Date.current
      select policy.store_name, from: "Store Policy"
      click_button "Add Purchase"
    end
    assert_notice "Purchase added."
    assert_selector ".purchase-card h2", text: "Textbook"

    within(".purchase-card", text: "Textbook") { click_link "Edit", exact: true }
    within("dialog[open]") do
      # Whitespace passes HTML required validation but exercises the server's presence validation.
      fill_in "Item Name", with: "   "
      click_button "Save Purchase"
      assert_selector "[role='alert']", text: "Item name can't be blank"
      assert_field "Price", with: "49.99"
      fill_in "Item Name", with: "Updated Textbook"
      select "Keeping", from: "Status"
      click_button "Save Purchase"
    end
    assert_notice "Purchase updated."
    assert_current_path history_path
    within(".purchase-card", text: "Updated Textbook") { click_link "Delete", exact: true }
    within("dialog[open]") { click_link "Cancel", exact: true }
    assert_no_selector "dialog[open]"
    assert_selector ".purchase-card h2", text: "Updated Textbook"
    within(".purchase-card", text: "Updated Textbook") { click_link "Delete", exact: true }
    within("dialog[open]") { click_button "Delete Purchase" }
    assert_notice "Purchase deleted."
    assert_current_path history_path
    assert_no_selector ".purchase-card h2", text: "Updated Textbook"
  end

  test "first policy stays in the purchase modal and management saves refresh the policy list" do
    click_link "Add Purchase", exact: true
    within("dialog[open]") do
      click_link "Create Store Policy", exact: true
      fill_in "Store Name", with: "Campus Store"
      fill_in "Return Window (days)", with: "30"
      click_button "Create Store Policy"
      assert_selector "[role='status']", text: "Store return policy created."
      assert_select "Store Policy", selected: "Campus Store"
      fill_in "Item Name", with: "Notebook"
      fill_in "Price", with: "10.00"
      fill_in "Purchase Date", with: Date.current
      click_button "Add Purchase"
    end
    assert_notice "Purchase added."
    click_link "Store Policies", exact: true
    click_link "Create Store Policy", exact: true
    within("dialog[open]") do
      fill_in "Store Name", with: "Book Shop"
      fill_in "Return Window (days)", with: "14"
      click_button "Create Store Policy"
    end
    assert_notice "Store return policy created."
    assert_current_path store_policies_path
    within(".rc-policy-card", text: "Book Shop") { click_link "Edit", exact: true }
    within("dialog[open]") do
      fill_in "Store Name", with: "   "
      click_button "Save Store Policy"
      assert_selector "[role='alert']", text: "Store name can't be blank"
      assert_field "Return Window (days)", with: "14"
      fill_in "Store Name", with: "Updated Book Shop"
      click_button "Save Store Policy"
    end
    assert_notice "Store policy updated. Existing purchase deadlines are unchanged."
    assert_current_path store_policies_path
    assert_selector ".rc-policy-card h2", text: "Updated Book Shop"
  end

  test "mobile navigation fits its links and settings selection follows browser history" do
    [ 320, 390, 720 ].each do |width|
      page.current_window.resize_to(width, 844)
      nav = find(".rc-topnav")
      assert_operator nav.native.rect.height, :>=, 44
      assert page.evaluate_script("document.querySelector('.rc-topnav').scrollHeight <= document.querySelector('.rc-topnav').clientHeight")
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    end
    within("header") do
      find("summary[aria-label='Profile menu']").click
      click_link "Account Settings"
    end
    within(".rc-settings-nav") do
      click_link "Account security"
      assert_selector "a[href='#security'][aria-current='location'].active"
      click_link "Account details"
      assert_selector "a[href='#account'][aria-current='location'].active"
    end
    page.go_back
    assert_selector ".rc-settings-nav a[href='#security'][aria-current='location'].active"
    page.go_forward
    assert_selector ".rc-settings-nav a[href='#account'][aria-current='location'].active"
  end

  private

  def assert_notice(message)
    assert_selector "main [role='status']", text: message
    assert_no_selector "dialog[open]"
  end
end
