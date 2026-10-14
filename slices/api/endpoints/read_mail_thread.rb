# frozen_string_literal: true

module API
  module Endpoints
    class ReadMailThread < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.widen(
        MailThreads::HEAD,
        messages: Helpers::Schema.list(Serializers::MailMessage.reference).merge(description: "oldest first"),
      ).freeze

      include Deps[message_queries: "mail.repos.message_queries"]

      def handle(id:)
        thread = message_queries.thread(id)
        return not_found(Helpers::Wording.missing("mail thread", id)) if thread.nil?

        Success(
          serialized(Serializers::MailThread, thread).except("body", "reply_to")
            .merge(messages: serialized(Serializers::MailMessage, thread.mail_messages)),
        )
      end
    end
  end
end
