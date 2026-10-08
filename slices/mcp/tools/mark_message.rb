# frozen_string_literal: true

module MCP
  module Tools
    class MarkMessage < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: API::Schema::ID,
          status: { type: "string", enum: Blog::Types::MessageStatus.values },
        },
        required: %w[id status],
      }.freeze

      description "Mark one contact form message as unread, read or spam, as the admin's messages page does"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["write"]

      class << self
        def call(id:, status:, server_context:)
          case dep(:mark_message, server_context).call(id, status)
            in Success(message) then answer(id: message.id, status: message.status)
            in Failure(:not_found) then refuse(API::Wording.missing("message", id))
            else refuse("could not mark the message")
          end
        end
      end
    end
  end
end
