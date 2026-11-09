class ReminderMailer < ApplicationMailer
  def return_deadline(purchase)
    @purchase = purchase
    @deadline = purchase.return_by.strftime("%b %-d, %Y")
    store = " to #{purchase.store_name}" if purchase.store_name
    mail to: purchase.user.email_address, subject: "Return #{purchase.item_name}#{store} by #{@deadline}"
  end
end
