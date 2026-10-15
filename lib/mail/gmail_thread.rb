# frozen_string_literal: true

require "base64"
require "sanitize"

module Mail
  class GmailThread
    ADDRESS = /\A[^@[:space:]]+@[^@[:space:].]+(?:\.[^@[:space:].]+)+\z/
    BLANK = /\A[[:space:]]*\z/
    CATEGORY = "CATEGORY_"
    CHARSET = /charset="?([^";\s]+)/i
    EVERY = { trashed: "TRASH", draft: "DRAFT" }.freeze
    FLAGS = { starred: "STARRED", sent: "SENT", important: "IMPORTANT" }.freeze
    FROM = /\A\s*"?(?<name>[^"<]*?)"?\s*<(?<address>[^>]*)>\s*\z/
    HTML = "text/html"
    NO_SUBJECT = "(no subject)"
    NUL = "\0"
    PLAIN = "text/plain"
    RELAXED = Sanitize::Config::RELAXED
    SANITIZE = Sanitize::Config.freeze_config(
      Sanitize::Config.merge(
        RELAXED,
        elements: RELAXED[:elements] - %w[style],
        css: { properties: RELAXED[:css][:properties] - %w[position z-index] },
      ),
    )

    def initialize(json)
      @json = json
      @messages = json.fetch("messages", []).map { message(it) }
    end

    def attachments = @json.fetch("messages", []).to_h { [it.fetch("id"), files(it.fetch("payload", {}))] }

    def gmail_id = @json.fetch("id")

    def label_ids = labels.to_a

    attr_reader :messages

    def thread(now: Time.now)
      spam = every?("SPAM")

      {
        gmail_id:, subject: messages.first&.fetch(:subject) || NO_SUBJECT, status: status(spam),
        marked_spam_at: (now if spam), **flags,
        archived: !labels.include?("INBOX"), category:,
        received_at: messages.map { it[:received_at] }.max || now,
      }
    end

    private

    def attachment?(part) = !BLANK.match?(part["filename"].to_s)

    def body(payload)
      plain = text(payload, PLAIN)
      html = text(payload, HTML)

      { body: present(plain || (html && Sanitize.fragment(html))),
        html_body: html && Sanitize.fragment(html, SANITIZE) }
    end

    def category
      found = labels.find { it.start_with?(CATEGORY) }&.delete_prefix(CATEGORY)&.downcase

      found if Blog::Types::MailCategory.valid?(found)
    end

    def decode(part)
      charset = header(part, "Content-Type")&.[](CHARSET, 1) || Encoding::UTF_8.name

      utf8(Base64.urlsafe_decode64(part.dig("body", "data")), charset)
    end

    def every?(label) = message_labels.any? && message_labels.all? { it.include?(label) }

    def files(payload)
      parts(payload).select { attachment?(it) && !it["partId"].to_s.empty? }.map do |part|
        {
          part_id: part["partId"], filename: part["filename"], mime_type: part["mimeType"].to_s,
          size: part.dig("body", "size").to_i,
        }
      end
    end

    def flags = FLAGS.transform_values { labels.include?(it) }.merge(EVERY.transform_values { every?(it) })

    def header(part, name) = part.fetch("headers", []).find { it["name"].casecmp?(name) }&.fetch("value")

    def labels = @labels ||= message_labels.reduce(Set.new, :|)

    def message(json)
      payload = json.fetch("payload", {})

      {
        gmail_id: json.fetch("id"), subject: present(header(payload, "Subject")) || NO_SUBJECT,
        **sender(header(payload, "From").to_s), **body(payload),
        received_at: Time.at(json.fetch("internalDate").to_i/1000r),
      }
    end

    def message_labels = @message_labels ||= @json.fetch("messages", []).map { it.fetch("labelIds", []).to_set }

    def parts(part) = [part, *part.fetch("parts", []).flat_map { parts(it) }]

    def present(text)
      text = text&.delete(NUL)&.strip

      text unless text.nil? || BLANK.match?(text)
    end

    def sender(from)
      match = FROM.match(from)
      address = (match ? match[:address] : from).strip

      { reply_to: (address if ADDRESS.match?(address)), from_name: present(match&.[](:name)) }
    end

    def status(spam)
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
