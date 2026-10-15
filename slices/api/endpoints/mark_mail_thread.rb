# frozen_string_literal: true

module API
  module Endpoints
    class MarkMailThread < Endpoint
      STATUS = { type: "string", enum: Blog::Types::MessageStatus.values }.freeze
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, status: STATUS },
        required: %w[id status],
      }.freeze
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, status: STATUS }).freeze

      include Deps[mark_message: "mail.operations.mark_message"]

      def handle(id:, status:)
        case mark_message.call(id, status)
          in Success(thread) then Success(id: thread.id, status: thread.status)
          in Failure(:not_found) then missing("mail thread", id)
          else failed("could not mark the mail thread")
        end
      end
    end
  end
end
