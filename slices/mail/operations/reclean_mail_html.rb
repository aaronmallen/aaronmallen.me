# frozen_string_literal: true

module Mail
  module Operations
    class RecleanMailHtml < Blog::Operation
      include Deps[google: "google.client", gmail_recleans: "repos.gmail_recleans"]

      def call(after = 0) = step recleaned(after)

      private

      def reclean(client, id, address, gmail_id)
        thread = SyncGmail::Mailbox.new(client, address).get("threads/#{gmail_id}", format: "full")
        gmail_recleans.reclean(id, GmailThread.new(thread).messages)
      rescue Google::NotFound
        false
      end

      def recleaned(after)
        client = google.loaded
        rows = gmail_recleans.threads(client.holders(SyncGmail::SCOPE), after, SyncGmail::PAGE_SIZE)

        Success([rows.last&.first, rows.count { !reclean(client, *it) }])
      rescue Google::RateLimited => e
        Failure([:gmail_rate_limited, e.message])
      rescue Google::Error => e
        Failure([:gmail_failed, e.message])
      end
    end
  end
end
