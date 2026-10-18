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

      include Deps[change_thread: "mail.operations.change_thread"]

      def handle(id:, status:)
        case change_thread.call(id, status)
          in Success(thread) then Success(id: thread.id, status: thread.status)
          in Failure(:not_found) then missing("mail thread", id)
          in unmatched then unhandled(unmatched, "could not mark the mail thread")
        end
      end
    end
  end
end
