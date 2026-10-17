# frozen_string_literal: true

module Mail
  module Operations
    class SaveDraft < Blog::Operation
      HEADERS = %w[to cc bcc subject].freeze
      LISTED = 500

      include Deps[
        google: "google.client",
        gmail_mutations: "repos.gmail_mutations",
        gmail_queries: "repos.gmail_queries",
        parse_gmail_thread: "operations.parse_gmail_thread",
        send_mail: "operations.send_mail",
      ]

      def call(params)
        fields = send_mail.form(params)
        account = step send_mail.sender(fields[:from])
        draft = step saved(account, fields)

        store(account, draft.fetch("message"))
        draft.fetch("id")
      rescue Google::Error => e
        Failure([:gmail_failed, e.message])
      end

      def values(thread)
        address = thread&.draft && gmail_queries.address(thread.mail_account_id)
        return unless address

        mailbox = Mailbox.new(google, address)
        id = draft_id(mailbox, thread.gmail_id)
        id && opened(id, mailbox.get("drafts/#{id}", format: "full").fetch("message"), thread)
      rescue Google::Error
        nil
      end

      private

      def create(account, message) = mailbox(account).post("drafts", { message: })

      def draft_id(mailbox, gmail_id)
        listed = mailbox.get("drafts", maxResults: LISTED).fetch("drafts", [])
        listed.find { it.dig("message", "threadId") == gmail_id }&.fetch("id")
      end

      def kept(account, gmail_id)
        mailbox(account).thread(gmail_id, format: "minimal").fetch("messages", []).map { it.fetch("id") }
      end

      def mailbox(account) = Mailbox.new(google, account.address)

      def opened(id, message, thread)
        headers = message.dig("payload", "headers").to_h { [it["name"].downcase, it["value"]] }
        letter = parsed(thread.gmail_id, message).messages.first

        {
          draft: id, from: thread.mail_account_id.to_s, html: letter[:html_body], body: letter[:body],
          **HEADERS.to_h { [it.to_sym, headers[it]] },
        }
      end

      def parsed(gmail_id, message) = parse_gmail_thread.call({ "id" => gmail_id, "messages" => [message] })

      def saved(account, fields)
        html = fields[:body]
        outgoing = Outgoing.new(from: account.address, **fields.slice(:to, :cc, :bcc, :subject), html:)
        message = { raw: outgoing.raw }
        id = fields[:draft]

        Success(id ? update(account, id, message) : create(account, message))
      end

      def store(account, message)
        gmail_id = message.fetch("threadId")
        id = gmail_mutations.thread_id(account.id, gmail_id)
        return send_mail.mirror(account, gmail_id) unless id

        kept = kept(account, gmail_id)
        full = mailbox(account).get("messages/#{message.fetch('id')}", format: "full")
        gmail_mutations.store_draft(id, parsed(gmail_id, full), kept)
      end

      def update(account, id, message)
        mailbox(account).put("drafts/#{id}", { id:, message: })
      rescue Google::NotFound
        create(account, message)
      end
    end
  end
end
