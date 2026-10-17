# frozen_string_literal: true

module Mail
  module Structs
    GmailThread = Data.define(:gmail_id, :label_ids, :messages, :attachments, :row) do
      def thread(now: Time.now)
        spam = row[:status] == Blog::Types::MessageStatus["spam"]

        { gmail_id:, **row, marked_spam_at: (now if spam), received_at: row[:received_at] || now }
      end
    end
  end
end
