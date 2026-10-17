# frozen_string_literal: true

require "base64"

module Mail
  module Operations
    class DownloadAttachment < Blog::Operation
      include Deps[
        google: "google.client",
        gmail_queries: "repos.gmail_queries",
        thread_queries: "repos.thread_queries",
      ]

      def call(message_id, part_id)
        attachment = step found(thread_queries.attachment(message_id, part_id))
        message = attachment.mail_message
        address = step found(gmail_queries.address(message.mail_thread.mail_account_id))

        step fetched(attachment, Mailbox.new(google, address), "messages/#{message.gmail_id}")
      end

      private

      def body(part, mailbox, path)
        data = part.dig("body", "data")
        data ||= mailbox.get("#{path}/attachments/#{part.dig('body', 'attachmentId')}").fetch("data")

        Base64.urlsafe_decode64(data)
      end

      def fetched(attachment, mailbox, path)
        payload = mailbox.get(path, format: "full").fetch("payload")
        part = parts(payload).find { it["partId"] == attachment.part_id }

        part ? Success([attachment, body(part, mailbox, path)]) : Failure(:not_found)
      rescue Google::NotFound
        Failure(:not_found)
      rescue Google::Error => e
        Failure([:gmail_failed, e.message])
      end

      def parts(part) = [part, *part.fetch("parts", []).flat_map { parts(it) }]
    end
  end
end
