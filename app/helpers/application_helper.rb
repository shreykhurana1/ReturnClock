module ApplicationHelper
  def signup_password_errors(user, attribute)
    user.errors.where(attribute).map do |error|
      if error.type.is_a?(String)
        "Include uppercase and lowercase letters, a number, and a symbol."
      else
        error.message
      end
    end
  end
end
