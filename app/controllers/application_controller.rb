class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :use_user_time_zone

  private
    # Dates such as "today" and "days left" follow the signed-in user's time zone.
    def use_user_time_zone(&block)
      Time.use_zone(Current.user&.time_zone || Time.zone.name, &block)
    end
end
