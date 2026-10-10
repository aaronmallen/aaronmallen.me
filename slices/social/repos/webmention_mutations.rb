# frozen_string_literal: true

module Social
  module Repos
    class WebmentionMutations < DB::Repo
      include Dry::Monads[:result]

      APPROVED = Blog::Types::WebmentionStatus["approved"]
      IGNORED = Blog::Types::WebmentionStatus["ignored"]
      RESENT_FIELDS = %i[author_name author_url excerpt type].freeze
      SETTINGS_ID = 1
      SPAM = Blog::Types::WebmentionStatus["spam"]

      root :webmentions

      stamped_commands :create, :update

      def approve(id) = update(id, status: APPROVED, spam_reason: nil)

      def claim_receipt(post_id:, source_url:, visitor_hashes:, since:, limit:, total_limit:)
        receipt = webmention_receipts.claim(post_id:, source_url:, visitor_hashes:, since:, limit:, total_limit:)&.first

        receipt ? Success(receipt) : Failure(:throttled)
      end

      def delete_by_source(post_id, source_url) = webmentions.for_post(post_id).from_source(source_url).delete

      def delete_receipts_before(time) = webmention_receipts.received_before(time).delete

      def hold(**) = held_webmentions.hold(**)

      def ignore(id) = update(id, status: IGNORED, spam_reason: nil)

      def mark_spam(id, reason = nil) = update(id, status: SPAM, spam_reason: reason)

      def release(id) = held_webmentions.by_pk(id).delete

      def see(id, at) = update(id, seen_at: at)

      def snooze(id, ends_at) = update(id, snoozed_until: ends_at)

      def store(**attrs)
        written = attrs.merge(author_url: Webmentions::AuthorUrl.normalize(attrs[:author_url]))

        webmentions.store(resent: written.slice(*RESENT_FIELDS).keys, **written)
      end

      def update_settings(**attrs)
        transaction do
          webmention_settings.claim(SETTINGS_ID)
          webmention_settings.by_pk(SETTINGS_ID).stamped(:update).call(**attrs)
        end
      end
    end
  end
end
