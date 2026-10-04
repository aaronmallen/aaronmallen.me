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

          case snooze_attention.call(kind, Blog::Types::IdParam[request.params[:record_id]])
          in Success(_)
            toast(response, SNOOZED)
            response.redirect_to(routes.path(:admin_root))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
