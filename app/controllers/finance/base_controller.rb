module Finance
  class BaseController < ApplicationController
    before_action :require_owner

    private

    def require_owner
      redirect_to dashboard_path unless Current.user&.owner?
    end
  end
end
