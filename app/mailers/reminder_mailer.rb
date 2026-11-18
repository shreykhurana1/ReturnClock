class ReminderMailer < ApplicationMailer
  def return_deadline(purchase)
    @purchase = purchase
    @store_name = purchase.store_policy.store_name
    @deadline = purchase.return_by.strftime("%b %-d, %Y")
    mail to: purchase.user.email_address, subject: "Return #{purchase.item_name} to #{@store_name} by #{@deadline}"
  end
end
