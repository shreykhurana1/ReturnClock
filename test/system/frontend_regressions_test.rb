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
      assert page.evaluate_script("document.activeElement === document.querySelector(\"dialog[open] [role='alert']\")")
      assert_field "Price", with: "49.99"
      fill_in "Item Name", with: "Updated Textbook"
      select "Keeping", from: "Status"
      click_button "Save Purchase"
    end
    assert_current_path dashboard_path
    assert_no_selector "dialog[open]"
    assert_selector ".rc-toast", text: "Updated Textbook moved to History."
    assert_no_selector ".purchase-card h2", text: "Updated Textbook"
    visit history_path
    within(".purchase-card", text: "Updated Textbook") { click_link "Edit", exact: true }
    within("dialog[open]") do
      click_link "Delete Purchase", exact: true
      click_link "Cancel", exact: true
      assert_field "Item Name", with: "Updated Textbook"
      click_link "Delete Purchase", exact: true
      click_button "Delete Purchase"
    end
    assert_notice "Purchase deleted."
    assert_current_path history_path
    assert_no_selector ".purchase-card h2", text: "Updated Textbook"
  end

  test "first policy stays in the purchase modal and management saves refresh the policy list" do
    click_link "Add Purchase", exact: true
    within("dialog[open]") do
      fill_in "Item Name", with: "Notebook"
      fill_in "Price", with: "10.00"
      fill_in "Purchase Date", with: Date.current - 3
      select "Returning", from: "Status"
      click_button "Create Store Policy", exact: true
      fill_in "Store Name", with: "   "
      fill_in "Return Window (days)", with: "30"
      click_button "Create Store Policy"
      assert_selector "[role='alert']", text: "Store name can't be blank"
      assert page.evaluate_script("document.activeElement === document.querySelector(\"dialog[open] [role='alert']\")")
      assert_field "Return Window (days)", with: "30"
      fill_in "Store Name", with: "Campus Store"
      click_button "Create Store Policy"
      assert_selector "[role='status']", text: "Store return policy created."
      assert_select "Store Policy", selected: "Campus Store — 30 days"
      assert_purchase_fields "Notebook", "10.00", Date.current - 3, "Returning"
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

  test "standalone mobile purchase keeps edited sample values through policy errors and returning without saving" do
    page.current_window.resize_to(390, 844)
    visit new_purchase_path(sample: "Wireless Headphones")
    assert_no_selector "dialog"
    fill_in "Item Name", with: "My edited headphones"
    fill_in "Price", with: "29.95"
    fill_in "Purchase Date", with: Date.current - 2
    select "Keeping", from: "Status"
    click_button "Create Store Policy", exact: true
    fill_in "Store Name", with: "   "
    fill_in "Return Window (days)", with: "14"
    click_button "Create Store Policy"
    assert_selector "[role='alert']", text: "Store name can't be blank"
    click_link "Back to Add Purchase"
    assert_purchase_fields "My edited headphones", "29.95", Date.current - 2, "Keeping"
    assert_equal 0, @user.store_policies.count

    click_button "Create Store Policy", exact: true
    fill_in "Store Name", with: "Mobile Shop"
    fill_in "Return Window (days)", with: "14"
    click_button "Create Store Policy"
    assert_select "Store Policy", selected: "Mobile Shop — 14 days"
    assert_purchase_fields "My edited headphones", "29.95", Date.current - 2, "Keeping"
    fill_in "Item Name", with: "   "
    click_button "Add Purchase"
    assert_selector "[role='alert']", text: "Item name can't be blank"
    assert_purchase_fields "   ", "29.95", Date.current - 2, "Keeping"
    fill_in "Item Name", with: "My edited headphones"
    # Enter must still submit the purchase, not open policy creation again.
    find_field("Item Name").send_keys(:enter)
    assert_notice "Purchase added."
    assert_current_path history_path
    assert_selector ".purchase-card h2", text: "My edited headphones"
    assert_equal Date.current + 12, @user.purchases.sole.return_by
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
      click_link "Change Password"
      assert_selector "a[href='#security'][aria-current='location'].active"
      click_link "Account details"
      assert_selector "a[href='#account'][aria-current='location'].active"
    end
    page.go_back
    assert_selector ".rc-settings-nav a[href='#security'][aria-current='location'].active"
    page.go_forward
    assert_selector ".rc-settings-nav a[href='#account'][aria-current='location'].active"
  end

  test "card quick actions update the card in place and move it to history on refresh" do
    page.current_window.resize_to(900, 600)
    policy = @user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    @user.purchases.create!(store_policy: policy, item_name: "Boots", price: 80, purchase_date: Date.current - 5)
    visit dashboard_path

    page.execute_script("window.scrollTo(0, 250)")
    page.execute_script("Array.from(document.querySelectorAll('.rc-quick-action button')).find(button => button.textContent.trim() === 'Return it').click()")
    assert_selector ".purchase-card .rc-chip", text: "Returning"
    assert_selector ".rc-toast", text: "Boots marked as returning."
    assert_no_selector ".rc-toast", wait: 4
    assert_current_path dashboard_path
    assert_operator page.evaluate_script("window.scrollY").to_i, :>, 0
    within(".purchase-card", text: "Boots") do
      assert_no_button "Keep it"
      click_button "Sent it back"
    end
    assert_selector ".rc-toast", text: "Boots marked as shipped back."
    within(".purchase-card", text: "Boots") do
      assert_selector ".rc-outcome", text: "Shipped back on"
      click_button "Refund received"
    end
    assert_selector ".rc-toast", text: "Refund received for Boots. Moved to History."
    assert_current_path dashboard_path
    assert_no_selector ".purchase-card h2", text: "Boots"

    visit history_path
    within(".purchase-card", text: "Boots") do
      assert_selector ".rc-chip", text: "Refunded"
      assert_selector ".rc-outcome", text: "Refunded on"
    end
  end

  test "changing the alert lead time updates the days-left urgency while Active stays green" do
    policy = @user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    @user.purchases.create!(store_policy: policy, item_name: "Lamp", price: 20, purchase_date: Date.current - 25)
    visit dashboard_path
    assert_selector ".purchase-card .rc-chip-success", text: "Active"
    assert_selector ".purchase-card .rc-days-warning"
    assert_equal "rgb(180, 105, 7)", page.evaluate_script("getComputedStyle(document.querySelector('.purchase-card .rc-days-warning')).color")

    visit settings_path
    within(".rc-settings-nav") do
      click_link "Deadline alerts"
      assert_selector "a[href='#alerts'][aria-current='location'].active"
    end
    assert_select "Alert me", selected: "2 days before"
    select "1 week before", from: "Alert me"
    click_button "Save settings"
    assert_selector "main [role='status']", text: "Settings updated."
    assert_select "Alert me", selected: "1 week before"

    visit dashboard_path
    assert_selector ".purchase-card .rc-chip-success", text: "Active"
    assert_selector ".purchase-card .rc-days-danger"
    assert_equal "rgb(186, 54, 73)", page.evaluate_script("getComputedStyle(document.querySelector('.purchase-card .rc-days-danger')).color")
  end

  test "real purchase quick actions fit narrow cards without overlapping or clipped labels" do
    policy = @user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    %w[active returning shipped_back refund_pending].each do |status|
      @user.purchases.create!(store_policy: policy, item_name: "Layout #{status}", price: 80,
        purchase_date: Date.current - 5, status: status)
    end
    visit dashboard_path
    assert_selector ".purchase-card[data-sample='false']", count: 4
    [ 320, 390, 720, 1400 ].each do |width|
      page.current_window.resize_to(width, 1000)
      assert page.evaluate_script(<<~JS), "Upcoming purchases must appear above statistics at #{width}px"
        document.querySelector('#dashboard-purchases').getBoundingClientRect().bottom <=
          document.querySelector('.rc-stat-grid').getBoundingClientRect().top
      JS
      problems = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('.purchase-card')).flatMap(card => {
          const bounds = card.getBoundingClientRect()
          const controls = Array.from(card.querySelectorAll('.rc-card-actions .rc-btn'))
            .filter(control => control.checkVisibility())
          const issues = []
          controls.forEach((control, index) => {
            const rect = control.getBoundingClientRect()
            const label = control.textContent.trim()
            if (rect.left < bounds.left - 1 || rect.right > bounds.right + 1 || control.scrollWidth > control.clientWidth + 1) {
              issues.push(`${card.dataset.status}: clipped ${label}`)
            }
            controls.slice(index + 1).forEach(other => {
              const next = other.getBoundingClientRect()
              if (Math.min(rect.right, next.right) - Math.max(rect.left, next.left) > 1 &&
                  Math.min(rect.bottom, next.bottom) - Math.max(rect.top, next.top) > 1) {
                issues.push(`${card.dataset.status}: overlapping ${label} and ${other.textContent.trim()}`)
              }
            })
          })
          return issues
        })
      JS
      assert_empty problems, "Action layout at #{width}px: #{problems.join(', ')}"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    end
    within(".purchase-card", text: "Layout active") { click_button "Keep it" }
    assert_current_path dashboard_path
    assert_no_selector ".purchase-card h2", text: "Layout active"
  end

  test "a purchase draft survives an expired session and sign-in" do
    policy = @user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    visit new_purchase_path

    fill_in "Item Name", with: "Session draft"
    fill_in "Price", with: "29.95"
    fill_in "Purchase Date", with: Date.current
    select policy.label, from: "Store Policy"
    @user.sessions.destroy_all

    click_button "Add Purchase"
    assert_selector "h1", text: "Sign In"
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "Password1!"
    click_button "Sign In"
    assert_selector "main h1", text: "Dashboard"

    visit new_purchase_path
    assert_field "Item Name", with: "Session draft"
    assert_field "Price", with: "29.95"
    assert_field "Purchase Date", with: Date.current.iso8601
    assert_select "Store Policy", selected: policy.label
    assert_selector ".rc-draft-notice", text: "Unsaved changes restored."
  end
  test "refreshing the purchase page restores the typed draft" do
    policy = @user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    visit new_purchase_path

    fill_in "Item Name", with: "Refresh draft"
    fill_in "Price", with: "9.99"
    fill_in "Purchase Date", with: Date.current
    select policy.label, from: "Store Policy"
    page.refresh

    assert_field "Item Name", with: "Refresh draft"
    assert_field "Price", with: "9.99"
    assert_field "Purchase Date", with: Date.current.iso8601
    assert_select "Store Policy", selected: policy.label
    assert_selector ".rc-draft-notice", text: "Unsaved changes restored."
  end
  test "closing and reopening the purchase modal restores an unsaved draft" do
    policy = @user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    visit dashboard_path
    click_link "Add Purchase", exact: true

    within("dialog[open]") do
      fill_in "Item Name", with: "Draft notebook"
      fill_in "Price", with: "12.34"
      fill_in "Purchase Date", with: Date.current
      select policy.label, from: "Store Policy"
      find("button.rc-dialog-close").click
    end

    assert_no_selector "dialog[open]"
    click_link "Add Purchase", exact: true

    within("dialog[open]") do
      assert_field "Item Name", with: "Draft notebook"
      assert_field "Price", with: "12.34"
      assert_field "Purchase Date", with: Date.current.iso8601
      assert_select "Store Policy", selected: policy.label
      assert_selector ".rc-draft-notice", text: "Unsaved changes restored."
      click_button "Add Purchase"
    end

    assert_notice "Purchase added."
    assert_selector ".purchase-card h2", text: "Draft notebook"

    click_link "Add Purchase", exact: true
    within("dialog[open]") do
      assert_field "Item Name", with: ""
      assert_no_selector ".rc-draft-notice:not([hidden])"
    end
  end

  test "creating a policy while editing a purchase returns to the same form with changes intact" do
    policy = @user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    @user.purchases.create!(store_policy: policy, item_name: "Textbook", price: "40.00",
      purchase_date: Date.current - 5, status: "active")
    visit dashboard_path

    within(".purchase-card", text: "Textbook") { click_link "Edit", exact: true }

    within("dialog[open]") do
      fill_in "Item Name", with: "Edited textbook"
      fill_in "Price", with: "49.99"
      fill_in "Purchase Date", with: Date.current - 2
      click_button "Create Store Policy", exact: true
      fill_in "Store Name", with: "Edited Store"
      fill_in "Return Window (days)", with: "45"
      click_button "Create Store Policy"
      assert_field "Item Name", with: "Edited textbook"
      assert_field "Price", with: "49.99"
      assert_field "Purchase Date", with: (Date.current - 2).iso8601
      assert_select "Store Policy", selected: "Edited Store — 45 days"
      click_button "Save Purchase"
    end

    assert_current_path dashboard_path
    assert_no_selector "dialog[open]"
    assert_selector ".rc-toast", text: "Edited textbook updated."
    assert_selector ".purchase-card h2", text: "Edited textbook"
  end

  test "closing and reopening a store policy form restores its draft" do
    visit store_policies_path
    click_link "Create Store Policy", exact: true

    within("dialog[open]") do
      fill_in "Store Name", with: "Draft store"
      fill_in "Return Window (days)", with: "21"
      find("button.rc-dialog-close").click
    end

    assert_no_selector "dialog[open]"
    click_link "Create Store Policy", exact: true

    within("dialog[open]") do
      assert_field "Store Name", with: "Draft store"
      assert_field "Return Window (days)", with: "21"
      assert_selector ".rc-draft-notice", text: "Unsaved changes restored."
    end
  end

  test "store policy edit stays in the card corner and delete lives in the editor" do
    policy = @user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    visit store_policies_path

    within(".rc-policy-card", text: policy.store_name) do
      assert_selector ".rc-policy-card-header .rc-card-edit", text: "Edit"
      assert_no_selector "form button", text: /Delete/
      click_link "Edit", exact: true
    end

    within("dialog[open]") { assert_button "Delete Store Policy" }
    accept_confirm("Delete this store policy?") do
      within("dialog[open]") { click_button "Delete Store Policy" }
    end

    assert_notice "Store policy deleted."
    assert_no_selector ".rc-policy-card h2", text: policy.store_name
  end

  test "pagination preserves the page scroll position" do
    page.current_window.resize_to(900, 600)
    policy = @user.store_policies.create!(store_name: "Campus Store", window_days: 30)
    8.times do |index|
      @user.purchases.create!(store_policy: policy, item_name: "Scroll #{index}", price: 20,
        purchase_date: Date.current - 5, status: "active")
    end
    visit dashboard_path
    assert_selector ".rc-page-status", text: "Page 1 of 2"

    page.execute_script("window.scrollTo(0, 400)")
    page.execute_script("document.querySelector('.rc-pagination a[rel=next]').click()")
    assert_selector ".rc-page-status", text: "Page 2 of 2"

    deadline = Time.current + 2
    sleep 0.05 while page.evaluate_script("window.scrollY").to_i.zero? && Time.current < deadline
    assert_operator page.evaluate_script("window.scrollY").to_i, :>, 0
  end

  private

  def assert_purchase_fields(name, price, date, status)
    assert_field "Item Name", with: name
    assert_field "Price", with: price
    assert_field "Purchase Date", with: date.iso8601
    assert_select "Status", selected: status
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  end

  def assert_notice(message)
    assert_selector "main [role='status']", text: message
    assert_no_selector "dialog[open]"
    # The notice can be visible before Turbo finishes the visit and restores scrolling.
    assert_no_selector "html[aria-busy='true']", wait: 5
  end
end
