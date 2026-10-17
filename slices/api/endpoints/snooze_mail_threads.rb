# frozen_string_literal: true

module API
  module Endpoints
    class SnoozeMailThreads < Endpoint
      SCHEMA = Helpers::Schema.widen(
        MailThreads::BULK, snoozed_until: SnoozeInboxRow::SCHEMA.dig(:properties, :snoozed_until),
      ).freeze
      REPLY = BulkMailThreadEndpoint::REPLY

      include Deps[message_queries: "mail.repos.message_queries", snooze_inbox: "operations.snooze_inbox"]

      def handle(ids:, snoozed_until:)
        case snooze_inbox.call({ messages: ids, snoozed_until: })
          in Success(messages:) then Success(mail_threads: answered(messages))
          in Failure[:record, _, id, _] then invalid(ids: [Helpers::Wording.missing("mail thread", id)])
          in Failure(:invalid | :past => code) then invalid(snoozed_until: [Helpers::Wording::SNOOZE_REFUSALS[code]])
          else failed("could not snooze the mail threads")
        end
      end

      private

      def answered(snoozed) = serialized(Serializers::MailThread, message_queries.by_ids_in_order(snoozed.map(&:id)))
    end
  end
end
