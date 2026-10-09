# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkMessageEndpoint < Endpoint
      SCHEMA = Messages::BULK
      REPLY = Helpers::Schema.object({ messages: Helpers::Schema.list(Serializers::Message.reference) }).freeze

      include Deps[
        act_on_messages: "contact.operations.act_on_messages",
        message_queries: "contact.repos.message_queries",
      ]

      def handle(ids:) = acted(ids)

      private

      def acted(ids, **input)
        case act_on_messages.call({ act: self.class::ACT, ids:, **input })
          in Success[*messages] then Success(messages: answered(messages))
          in Failure[:record, id, :not_found] then invalid(ids: [Helpers::Wording.missing("message", id)])
          in Failure[:record, id, _] then failed(format(Messages::UNCHANGED, id))
          in Failure[:invalid, errors] then rejected(flat(errors), Messages::COMPLAINTS)
          else failed(Helpers::Wording::UNSAVED)
        end
      end

      def answered(messages) = serialized(Serializers::Message, messages.map { message_queries.by_id(it.id) })
    end
  end
end
