# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class SeeAll < Action
        KINDS = {
          tasks: "inbox_page.toasts.see_all.kinds.tasks",
          messages: "inbox_page.toasts.see_all.kinds.messages",
          webmentions: "inbox_page.toasts.see_all.kinds.webmentions",
        }.freeze
        TOASTS = "inbox_page.toasts.see_all"

        include Deps[clear_inbox: "api.operations.clear_inbox"]

        def handle(request, response)
          case clear_inbox.call(request.params.to_h)
          in Success(cleared) then toast(response, "#{TOASTS}.done", count: cleared.values.sum(&:size))
          in Failure[:record, kind, id, reason] then failed(response, kind, id, reason)
          in Failure[:invalid, _] then toast(response, "#{TOASTS}.empty")
          else halt 500
          end

          response.redirect_to(routes.path(:admin_inbox))
        end

        private

        def failed(response, kind, id, reason)
          code = reason == :not_found ? reason : :other

          toast(response, "#{TOASTS}.failed.#{code}", kind: i18n.t!(KINDS.fetch(kind)), id:)
        end
      end
    end
  end
end
