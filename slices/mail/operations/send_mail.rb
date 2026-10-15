# frozen_string_literal: true

module Mail
  module Operations
    class SendMail < Blog::Operation
      ADDRESS_SPLIT = /[\s,;]+/
      ARCHIVE = Blog::Types::MessageBulkAction["archive"]
      GMAIL = Blog::Types::MailProvider["gmail"]
      MESSAGE_ID = "Message-ID"
      SCOPE = "https://www.googleapis.com/auth/gmail.send"

      include Deps[
        google: "google.client",
        change_thread: "operations.change_thread",
        contract: "contracts.send_contract",
        gmail_mutations: "repos.gmail_mutations",
        thread_queries: "repos.thread_queries",
      ]

      def call(params)
        fields = step validate(params)
        account = step sender(fields[:from])
        thread = step replying(fields[:thread])

        step deliver(account, thread, fields, archive: Blog::Types::Checkbox[params[:archive]])
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
        json = google.get("#{SyncGmail::GMAIL}/threads/#{gmail_id}", account: account.address, format: "full")
        gmail_mutations.store_thread(account.id, GmailThread.new(json))
      end

      def senders(accounts = thread_queries.accounts)
        addresses = google.holders(SCOPE)

        accounts.select { it.provider == GMAIL && it.sends && addresses.include?(it.address) }
      end

      private

      def addresses(value) = value.to_s.split(ADDRESS_SPLIT).reject(&:empty?)

      def deliver(account, thread, fields, archive:)
        same = thread&.mail_account_id == account.id
        message = outgoing(account, fields, in_reply_to: (message_id(account, thread) if same))
        sent = post(account, message, (thread.gmail_id if same), fields[:draft])
      rescue Google::Error => e
        Failure([:gmail_failed, e.message])
      else
        Success(settle(account, thread, sent.fetch("threadId"), archive:))
      end

      def files(params)
        Array(params[:files]).select { it.is_a?(::Hash) && it[:tempfile] }.map do |file|
          { filename: file[:filename].to_s, type: file[:type], data: File.binread(file[:tempfile].path) }
        end
      end

      def message_id(account, thread)
        last = thread.mail_messages.rfind(&:gmail_id)
        return unless last

        url = "#{SyncGmail::GMAIL}/messages/#{last.gmail_id}"
        found = google.get(url, account: account.address, format: "metadata", metadataHeaders: MESSAGE_ID)
        found.dig("payload", "headers")&.find { it["name"].casecmp?(MESSAGE_ID) }&.fetch("value")
      end

      def outgoing(account, fields, in_reply_to:)
        html = [fields[:body], (account.signature if fields[:signature])].compact.join("<br>")

        Outgoing.new(
          from: account.address, to: fields[:to], cc: fields[:cc], bcc: fields[:bcc], subject: fields[:subject],
          html:, in_reply_to:, files: fields[:files],
        )
      end

      def post(account, message, thread_id, draft)
        body = { raw: message.raw, threadId: thread_id }.compact
        return google.post("#{SyncGmail::GMAIL}/messages/send", body, account: account.address) unless draft

        google.post("#{SyncGmail::GMAIL}/drafts/send", { id: draft, message: body }, account: account.address)
      rescue Google::NotFound
        raise unless draft

        post(account, message, thread_id, nil)
      end

      def replying(id)
        return Success(nil) unless id

        found(thread_queries.by_id(id))
      end

      def sender(id)
        account = senders.find { it.id == id }

        account ? Success(account) : Failure([:invalid, { from: [Blog::Contract::FORMAT] }])
      end

      def settle(account, thread, gmail_id, archive:)
        change_thread.call(thread.id, ARCHIVE) if archive && thread
        mirror(account, gmail_id)
      rescue Google::Error
        gmail_id
      end

      def validate(params)
        fields = form(params)

        extra = { **fields.slice(:draft), signature: Blog::Types::Checkbox[params[:signature]], files: files(params) }

        validated(contract.call(fields)).fmap { it.merge(extra) }
      end
    end
  end
end
