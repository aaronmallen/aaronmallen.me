# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class Snooze < Action
        TOASTS = "inbox_page.toasts"

        include Deps[snooze_inbox_row: "api.operations.snooze_inbox_row"]

        def handle(request, response)
          picked = request.params[:pick] || request.params[:snoozed_until]

          case snooze_inbox_row.call(request.params[:kind], record_id(request), picked)
            in Success(snooze) then done(response, :snoozed, **until_words(snooze.snoozed_until))
            in Failure(:invalid | :past => refusal) then done(response, refusal)
            in Failure(:not_found) then halt 404
            else halt 500
          end
        end

        private

        def done(response, key, **)
          toast(response, "#{TOASTS}.#{key}", **)
          response.redirect_to(routes.path(:admin_inbox))
        end

        def until_words(time)
          {
            date: i18n.l(Blog::TimeZone.today(time), format: :medium),
            time: i18n.l(Blog::TimeZone.local(time), format: :clock),
          }
        end
      end
    end
  end
end
