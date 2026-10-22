# frozen_string_literal: true

module Mail
  module Operations
    class SendMail < Blog::Operation
      ARCHIVE = Blog::Types::MessageBulkAction["archive"]
      MESSAGE_ID = "Message-ID"

      include Deps[
        google: "google.client",
        change_thread: "operations.change_thread",
        contract: "contracts.send_contract",
        save_draft: "operations.save_draft",
        thread_queries: "repos.thread_queries",
      ]

      def call(params)
        fields = step validate(params)
        account = step save_draft.sender(fields[:from])
        thread = step replying(fields[:thread])

        step deliver(account, thread, fields, archive: Blog::Types::Checkbox[params[:archive]])
      end

      private

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

      def mailbox(account) = Mailbox.new(google, account.address)

      def message_id(account, thread)
        last = thread.mail_messages.rfind { it.gmail_id && !it.draft }
        return unless last

        found = mailbox(account).get("messages/#{last.gmail_id}", format: "metadata", metadataHeaders: MESSAGE_ID)
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
        return mailbox(account).post("messages/send", body) unless draft

        mailbox(account).post("drafts/send", { id: draft, message: body })
      rescue Google::NotFound
        raise unless draft

        post(account, message, thread_id, nil)
      end

      def replying(id)
        return Success(nil) unless id

        found(thread_queries.by_id(id))
      end

      def settle(account, thread, gmail_id, archive:)
        change_thread.call(thread.id, ARCHIVE) if archive && thread
        save_draft.mirror(account, gmail_id)
      rescue Google::Error
        gmail_id
      end

      def validate(params)
        fields = save_draft.form(params)

        extra = { **fields.slice(:draft), signature: Blog::Types::Checkbox[params[:signature]], files: files(params) }

        validated(contract.call(fields)).fmap { it.merge(extra) }
      end
    end
  end
end
