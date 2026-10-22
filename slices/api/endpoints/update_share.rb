# frozen_string_literal: true

module API
  module Endpoints
    class UpdateShare < Endpoint
      COMPLAINTS = Helpers::Upload::COMPLAINTS.merge(code: UpdateShortLink::COMPLAINTS[:code]).freeze
      CONTRACTS = [::Shares::Contracts::ShareContract].freeze
      FILENAME = { type: "string", description: "the name a download saves as; the link stays the same" }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          filename: FILENAME,
          code: { type: "string", description: "the share's new short code; the old link stops working" },
          alt_text: { type: "string", description: "the words that describe an image; empty to clear them" },
        },
        required: %w[id],
      }.freeze

      REPLY = Serializers::Share.reference

      include Deps[save_share: "shares.operations.save_share", share_queries: "shares.repos.share_queries"]

      def handle(id:, **fields)
        share = share_queries.find(id)
        return missing("share", id) unless share

        case save_share.call(id, { code: share.code, **fields })
          in Success(_) then Success(serialized(Serializers::Share, share_queries.find(id), settings:))
          in Failure[:invalid, errors] then rejected(errors, COMPLAINTS)
          in unmatched then unhandled(unmatched, Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
