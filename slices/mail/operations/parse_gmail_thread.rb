# frozen_string_literal: true

require "base64"
require "sanitize"

module Mail
  module Operations
    class ParseGmailThread
      BLANK = /\A[[:space:]]*\z/
      CATEGORY = "CATEGORY_"
      CHARSET = /charset="?([^";\s]+)/i
      EVERY = { trashed: "TRASH", draft: "DRAFT" }.freeze
      FLAGS = { starred: "STARRED", sent: "SENT", important: "IMPORTANT" }.freeze
      FROM = /\A\s*"?(?<name>[^"<]*?)"?\s*<(?<address>[^>]*)>\s*\z/
      HTML = "text/html"
      NBSP = " "
      NO_SUBJECT = "(no subject)"
      NUL = "\0"
      PLAIN = "text/plain"
      RELAXED = Sanitize::Config::RELAXED
      SANITIZE = Sanitize::Config.freeze_config(
        Sanitize::Config.merge(
          RELAXED,
          elements: RELAXED[:elements] - %w[style],
          attributes: { all: RELAXED[:attributes][:all] - %w[class id] },
          css: { properties: RELAXED[:css][:properties] - %w[position z-index] },
        ),
      )

      def call(json)
        raw = json.fetch("messages", [])
        sets = raw.map { it.fetch("labelIds", []).to_set }
        labels = sets.reduce(Set.new, :|)
        messages = raw.map { message(it) }

        Structs::GmailThread.new(
          gmail_id: json.fetch("id"), label_ids: labels.to_a, messages:, row: row(messages, labels, sets),
          attachments: raw.to_h { [it.fetch("id"), files(it.fetch("payload", {}))] },
        )
      end

      private

      def attachment?(part) = !BLANK.match?(part["filename"].to_s)

      def body(payload)
        plain = text(payload, PLAIN)
        html = text(payload, HTML)

        { body: present(plain || (html && html_text(html))),
          html_body: html && Sanitize.fragment(html, SANITIZE) }
      end

      def category(labels)
        found = labels.find { it.start_with?(CATEGORY) }&.delete_prefix(CATEGORY)&.downcase

        found if Blog::Types::MailCategory.valid?(found)
      end

      def decode(part)
        charset = header(part, "Content-Type")&.[](CHARSET, 1) || Encoding::UTF_8.name

        utf8(Base64.urlsafe_decode64(part.dig("body", "data")), charset)
      end

      def every?(sets, label) = sets.any? && sets.all? { it.include?(label) }

      def files(payload)
        parts(payload).select { attachment?(it) && !it["partId"].to_s.empty? }.map do |part|
          {
            part_id: part["partId"], filename: part["filename"], mime_type: part["mimeType"].to_s,
            size: part.dig("body", "size").to_i,
          }
        end
      end

      def header(part, name) = part.fetch("headers", []).find { it["name"].casecmp?(name) }&.fetch("value")

      def html_text(html) = Nokogiri::HTML5.fragment(Sanitize.fragment(html)).text.tr(NBSP, " ")

      def message(json)
        payload = json.fetch("payload", {})

        {
          gmail_id: json.fetch("id"), subject: present(header(payload, "Subject")) || NO_SUBJECT,
          **sender(header(payload, "From").to_s), **body(payload),
          received_at: Time.at(json.fetch("internalDate").to_i/1000r),
        }
      end

      def parts(part) = [part, *part.fetch("parts", []).flat_map { parts(it) }]

      def present(text)
        text = text&.delete(NUL)&.strip

        text unless text.nil? || BLANK.match?(text)
      end

      def row(messages, labels, sets)
        {
          subject: messages.first&.fetch(:subject) || NO_SUBJECT, status: status(every?(sets, "SPAM"), labels),
          **FLAGS.transform_values { labels.include?(it) }, **EVERY.transform_values { every?(sets, it) },
          archived: !labels.include?("INBOX"), category: category(labels),
          received_at: messages.map { it[:received_at] }.max,
        }
      end

      def sender(from)
        match = FROM.match(from)
        address = (match ? match[:address] : from).strip

        { reply_to: (address if Blog::Types::EmailAddress.valid?(address)), from_name: present(match&.[](:name)) }
      end

      def status(spam, labels)
        return Blog::Types::MessageStatus["spam"] if spam

        Blog::Types::MessageStatus[labels.include?("UNREAD") ? "unread" : "read"]
      end

      def text(payload, type)
        part = parts(payload).find { it["mimeType"] == type && it.dig("body", "data") && !attachment?(it) }

        part && decode(part).delete(NUL)
      end

      def utf8(data, charset)
        data.force_encoding(charset).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      rescue ArgumentError, EncodingError
        data.force_encoding(Encoding::UTF_8).scrub
      end
    end
  end
end
