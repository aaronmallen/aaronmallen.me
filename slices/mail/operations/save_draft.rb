# frozen_string_literal: true

module Mail
  module Operations
    class SaveDraft < Blog::Operation
      ADDRESS_SPLIT = /[\s,;]+/
      GMAIL = Blog::Types::MailProvider["gmail"]
      HEADERS = %w[to cc bcc subject].freeze
      LISTED = 500
      SCOPE = "https://www.googleapis.com/auth/gmail.send"

      include Deps[
        google: "google.client",
        gmail_mutations: "repos.gmail_mutations",
        gmail_queries: "repos.gmail_queries",
        parse_gmail_thread: "operations.parse_gmail_thread",
        thread_queries: "repos.thread_queries",
      ]

      def call(params)
        fields = form(params)
        account = step sender(fields[:from])

        step saved(account, fields)
      end

      def form(params)
        html = Blog::Types::OptionalText[params[:html]]

        {
          from: params[:from], to: addresses(params[:to]), cc: addresses(params[:cc]), bcc: addresses(params[:bcc]),
          subject: params[:subject], body: html ? Outgoing.clean(html) : Outgoing.from_text(params[:body]),
          **%i[thread draft].to_h { [it, Blog::Types::OptionalText[params[it]]] },
        }
      end

      def mirror(account, gmail_id)
        gmail_mutations.store_thread(account.id, parse_gmail_thread.call(mailbox(account).thread(gmail_id)))
      end

      def sender(id)
        account = senders.find { it.id == Blog::Types::IdParam[id] }

        account ? Success(account) : invalid(:from, Blog::Contract::FORMAT)
      end

      def senders(accounts = thread_queries.accounts)
        addresses = google.holders(SCOPE)

        accounts.select { it.provider == GMAIL && it.sends && addresses.include?(it.address) }
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

      def addresses(value) = value.to_s.split(ADDRESS_SPLIT).reject(&:empty?)

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
        outgoing = Outgoing.new(from: account.address, **fields.slice(:to, :cc, :bcc, :subject), html: fields[:body])
        message = { raw: outgoing.raw }
        id = fields[:draft]
        draft = id ? update(account, id, message) : create(account, message)

        store(account, draft.fetch("message"))
        Success(draft.fetch("id"))
      rescue Google::Error => e
        Failure([:gmail_failed, e.message])
      end

      def store(account, message)
        gmail_id = message.fetch("threadId")
        id = gmail_mutations.thread_id(account.id, gmail_id)
        return mirror(account, gmail_id) unless id

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
