# frozen_string_literal: true

module MCP
  module Tools
    class MarkMailThread < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: API::Helpers::Schema::ID,
          status: { type: "string", enum: Blog::Types::MessageStatus.values },
        },
        required: %w[id status],
      }.freeze

      description "Mark one mail thread from any account as unread, read or spam"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["mail"]

      class << self
        def call(id:, status:, server_context:)
          case dep(:mark_mail_thread, server_context).call(id, status)
            in Success(thread) then answer(id: thread.id, status: thread.status)
            in Failure(:not_found) then refuse(API::Helpers::Wording.missing("mail thread", id))
            else refuse("could not mark the mail thread")
          end
        end
      end
    end
  end
end
