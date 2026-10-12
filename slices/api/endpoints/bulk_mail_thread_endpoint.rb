# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkMailThreadEndpoint < Endpoint
      SCHEMA = MailThreads::BULK
      REPLY = Helpers::Schema.object({ mail_threads: Helpers::Schema.list(Serializers::MailThread.reference) }).freeze

      include Deps[
        act_on_messages: "mail.operations.act_on_messages",
        message_queries: "mail.repos.message_queries",
      ]

      def handle(ids:) = acted(ids)

      private

      def acted(ids, **input)
        case act_on_messages.call({ act: self.class::ACT, ids:, **input })
          in Success[*threads] then Success(mail_threads: answered(threads))
          in Failure[:record, id, :not_found] then invalid(ids: [Helpers::Wording.missing("mail thread", id)])
          in Failure[:record, id, _] then failed(format(MailThreads::UNCHANGED, id))
          in Failure[:invalid, errors] then rejected(flat(errors), MailThreads::COMPLAINTS)
          else failed(Helpers::Wording::UNSAVED)
        end
      end

      def answered(threads) = serialized(Serializers::MailThread, threads.map { message_queries.by_id(it.id) })
    end
  end
end
