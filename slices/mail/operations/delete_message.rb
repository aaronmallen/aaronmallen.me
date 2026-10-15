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

      def call(id)
        thread = step found(message_queries.by_id(id))
        step erased(thread)

        message_mutations.delete(id)
      end

      private

      def erased(thread)
        address = thread.gmail_id && gmail_queries.address(thread.mail_account_id)
        google.delete("#{ChangeThread::THREADS}/#{thread.gmail_id}", account: address) if address
        Success(thread)
      rescue Google::NotFound
        Success(thread)
      rescue Google::Error
        Failure(:gmail_failed)
      end
    end
  end
end
