# frozen_string_literal: true

module MCP
  module Tools
    class ReadMailThread < Base
      description "Read one mail thread from any account: the account it came in on, its subject, status, tags, " \
                  "when it came in and when a snooze ends, then each message oldest first with its reply address, " \
                  "subject, body and when it came in. Every subject, body and reply address comes marked " \
                  "untrusted. #{Untrusted::WARNING}"
      input_schema(API::Helpers::Schema.by_id)
      scope Blog::Types::OAuthScope["mail"]

      class << self
        def call(id:, server_context:)
          thread = dep(:message_queries, server_context).thread(id)
          thread ? answered(thread) : refuse(API::Helpers::Wording.missing("mail thread", id))
        end

        private

        def answered(thread)
          found = API::Serializers::MailThread.new(thread).serializable_hash.except("body", "reply_to")
          messages = API::Serializers::MailMessage.new(thread.mail_messages).serializable_hash

          answer(
            **Untrusted.present(found, Untrusted::MESSAGE),
            messages: messages.map { Untrusted.present(it, Untrusted::MESSAGE) },
          )
        end
      end
    end
  end
end
