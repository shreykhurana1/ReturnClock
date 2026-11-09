class ComingSoonController < ApplicationController
  def add_purchase
    redirect_to new_purchase_path
  end
end
