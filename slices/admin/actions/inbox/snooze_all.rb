# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class SnoozeAll < Snooze
        include Deps[snooze_inbox: "api.operations.snooze_inbox"]

        def handle(request, response)
          picked = request.params[:pick] || request.params[:snoozed_until]

          case snooze_inbox.call({ **request.params.to_h, snoozed_until: picked })
            in Success(snoozed) then snoozed_all(request, response, snoozed.values.flatten)
            in Failure[:record, kind, id, _]
              done(request, response, "see_all.failed.not_found", **named(kind), id:)
            in Failure[:invalid, _] then done(request, response, "see_all.empty")
            in Failure(:invalid | :past => refusal) then done(request, response, refusal)
            else halt 500
          end
        end

        private

        def named(kind) = { kind: i18n.t!(SeeAll::KINDS.fetch(kind)) }

        def snoozed_all(request, response, snoozes)
          done(request, response, :snoozed_all, count: snoozes.size, **until_words(snoozes.first.snoozed_until))
        end
      end
    end
  end
end
