# frozen_string_literal: true

module Admin
  module Actions
    module Today
      class RetryDeadJob < Action
        RETRIED = "today_page.toasts.retried"

        include Deps[act_on_set_job: "activity.operations.act_on_set_job"]

        def handle(request, response)
          result = act_on_set_job.call("dead", request.params[:jid], "retry")

          settle(response, result, RETRIED, routes.path(:admin_root))
        end
      end
    end
  end
end
