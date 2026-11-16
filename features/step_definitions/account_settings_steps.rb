When("I change my password using {string} to {string} with confirmation {string}") do |current_password, new_password, confirmation|
  fill_in "Current Password", with: current_password
  fill_in "New Password", with: new_password, exact: true
  fill_in "Confirm New Password", with: confirmation
  click_button "Change Password", exact: true
end
