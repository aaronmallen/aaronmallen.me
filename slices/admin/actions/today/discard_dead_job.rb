# frozen_string_literal: true

module Admin
  module Actions
    module Today
      class DiscardDeadJob < Action
        DISCARDED = "today_page.toasts.discarded"

        include Deps[act_on_set_job: "activity.operations.act_on_set_job"]

        def handle(request, response)
          result = act_on_set_job.call("dead", request.params[:jid], "discard")

          settle(response, result, DISCARDED, routes.path(:admin_root))
        end
      end
    end
  end
end
