# frozen_string_literal: true

module Admin
  module Actions
    module Today
      class RetryDeadJob < Action
        RETRIED = "today_page.toasts.retried"

        include Deps[retry_dead_job: "activity.operations.retry_dead_job"]

        def handle(request, response)
          settle(response, retry_dead_job.call(request.params[:jid]), RETRIED, routes.path(:admin_root))
        end
      end
    end
  end
end
