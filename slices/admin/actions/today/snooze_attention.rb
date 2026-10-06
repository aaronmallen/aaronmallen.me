# frozen_string_literal: true

module Admin
  module Actions
    module Today
      class SnoozeAttention < Action
        SNOOZED = "today_page.toasts.snoozed"

        include Deps[snooze_attention: "activity.operations.snooze_attention"]

        def handle(request, response)
          kind = request.params[:kind]
          halt 404 unless Blog::Types::AttentionKind.valid?(kind)

          result = snooze_attention.call(kind, Blog::Types::IdParam[request.params[:record_id]])
          settle(response, result, SNOOZED, routes.path(:admin_root))
        end
      end
    end
  end
end
