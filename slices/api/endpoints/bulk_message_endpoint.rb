# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkMessageEndpoint < Endpoint
      SCHEMA = Messages::BULK
      REPLY = Schema.object({ messages: Schema.list(Serializers::Message.reference) }).freeze

      include Deps[act_on_messages: "contact.operations.act_on_messages"]

      def handle(ids:)
        case act_on_messages.call({ act: self.class::ACT, ids: })
        in Success[*messages] then Success(messages: answered(messages))
        in Failure[:record, id, :not_found] then invalid(ids: [Wording.missing("message", id)])
        in Failure[:record, id, _] then failed(format(Messages::UNCHANGED, id))
        in Failure[:invalid, errors] then invalid(flat(errors))
        else failed(Wording::UNSAVED)
        end
      end

      private

      def answered(messages) = serialized(Serializers::Message, messages)
    end
  end
end
