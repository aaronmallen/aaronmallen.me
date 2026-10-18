# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class Snooze < Action
        TOASTS = "inbox_page.toasts"

        include Deps[snooze_inbox_row: "api.operations.snooze_inbox_row"]

        def handle(request, response)
          picked = request.params[:pick] || request.params[:snoozed_until]

          case snooze_inbox_row.call(kind(request), record_id(request), picked)
            in Success(snooze) then done(request, response, :snoozed, **until_words(snooze.snoozed_until))
            in Failure(:invalid | :past => refusal) then done(request, response, refusal)
            in Failure(:not_found) then halt :not_found
          end
        end

        private

        def back(request) = back_here(request) || routes.path(:admin_inbox)

        def done(request, response, key, **)
          toast(response, "#{TOASTS}.#{key}", **)
          response.redirect_to(back(request))
        end

        def kind(request) = request.params[:kind]

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
