# frozen_string_literal: true

module Admin
  module Actions
    module Today
      class DiscardDeadJob < Action
        DISCARDED = "today_page.toasts.discarded"

        include Deps[discard_dead_job: "activity.operations.discard_dead_job"]

        def handle(request, response)
          settle(response, discard_dead_job.call(request.params[:jid]), DISCARDED, routes.path(:admin_root))
        end
      end
    end
  end
end
