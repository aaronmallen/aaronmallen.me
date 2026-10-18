# frozen_string_literal: true

module API
  module Endpoints
    class SnoozeInbox < Endpoint
      CONTRACTS = [Contracts::ClearInboxContract].freeze
      EMPTY = "name at least one row to snooze"
      IDS = ClearInbox::IDS
      NOUNS = ClearInbox::NOUNS
      SCOPED = true

      SCHEMA = {
        additionalProperties: false,
        properties: {
          tasks: IDS.merge(description: "the ids of task rows from list_inbox to snooze"),
          messages: IDS.merge(description: "the ids of message rows from list_inbox to snooze; needs the mail scope"),
          webmentions: IDS.merge(description: "the ids of webmention rows from list_inbox to snooze"),
          snoozed_until: SnoozeInboxRow::SCHEMA.dig(:properties, :snoozed_until),
        },
        required: %w[snoozed_until],
      }.freeze

      REPLY = Helpers::Schema.object(
        {
          **NOUNS.transform_values { IDS },
          snoozed_until: { **Helpers::Schema::STAMP, description: "when the rows come back to the top of the inbox" },
        },
      ).freeze

      include Deps[snooze_inbox: "operations.snooze_inbox"]

      def handle(snoozed_until:, scopes:, **ids)
        refuse_mail(:messages, ids[:messages]&.any?, scopes) || snoozed(snoozed_until, ids)
      end

      private

      def reply(snoozed)
        ends_at = snoozed.values.flatten.first.snoozed_until

        { **snoozed.transform_values { it.map(&:id) }, snoozed_until: ends_at.utc.iso8601 }
      end

      def snoozed(snoozed_until, ids)
        case snooze_inbox.call({ **ids, snoozed_until: })
          in Success(snoozed) then Success(reply(snoozed))
          in Failure[:record, kind, id, _] then invalid(kind => [Helpers::Wording.missing(NOUNS.fetch(kind), id)])
          in Failure[:invalid, _] then invalid(input: [EMPTY])
          in Failure(:invalid | :past => code) then invalid(snoozed_until: [Helpers::Wording::SNOOZE_REFUSALS[code]])
          in unmatched then unhandled(unmatched, "could not snooze the rows")
        end
      end
    end
  end
end
