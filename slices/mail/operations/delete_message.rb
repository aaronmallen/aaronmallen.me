# frozen_string_literal: true

module Mail
  module Operations
    class DeleteMessage < Blog::Operation
      include Deps[
        google: "google.client",
        gmail_queries: "repos.gmail_queries",
        message_mutations: "repos.message_mutations",
        message_queries: "repos.message_queries",
      ]

      def call(id, client: google, local: true, remote: true)
        thread = step found(message_queries.by_id(id))
        step erased(thread, client) if remote
        return thread unless local

        message_mutations.delete(id)
      end

      private

      def erased(thread, client)
        address = thread.gmail_id && gmail_queries.address(thread.mail_account_id)
        Mailbox.new(client, address).delete("threads/#{thread.gmail_id}") if address
        Success(thread)
      rescue Google::NotFound
        Success(thread)
      rescue Google::Error
        Failure(:gmail_failed)
      end
    end
  end
end
