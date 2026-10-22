# frozen_string_literal: true

module API
  module Endpoints
    class SaveMailDraft < Endpoint
      ADDRESSES = { type: "string", description: "email addresses, split by commas" }.freeze
      GMAIL_FAILED = "Gmail would not save the draft; try again"
      NO_SENDER = "names no account that can send"
      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the account to send from, by the name list_mail_threads gives it" },
          to: ADDRESSES, cc: ADDRESSES, bcc: ADDRESSES, subject: Helpers::Schema::STRING,
          body: { type: "string", description: "the message, in plain text" },
          draft: {
            type: "string",
            description: "the draft to replace, as an earlier save answered it; leave it out to start one",
          },
        },
        required: %w[from],
      }.freeze
      REPLY = Helpers::Schema.object(
        { draft: { type: "string", description: "the draft, to replace in a later save" } },
      ).freeze

      include Deps[save_draft: "mail.operations.save_draft"]

      def handle(from:, **fields)
        account = save_draft.senders.find { it.name == from }
        return invalid(from: [NO_SENDER]) unless account

        case save_draft.call({ **fields, from: account.id })
          in Success(draft) then Success(draft:)
          in Failure[:gmail_failed, _] then failed(GMAIL_FAILED)
          in unmatched then unhandled(unmatched, "could not save the mail draft")
        end
      end
    end
  end
end
