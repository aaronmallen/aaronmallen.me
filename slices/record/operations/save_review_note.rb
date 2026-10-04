# frozen_string_literal: true

module Record
  module Operations
    class SaveReviewNote < Blog::Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["review_note"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        contract: "contracts.review_note_contract",
        review_note_repo: "repos.review_note_repo",
      ]

      def call(body, period:, on:, now: Time.now)
        attributes = step validated(contract.call(body:))
        starts_on, = Blog::ReviewRange.call(period, on)

        Success(transaction { save(attributes.fetch(:body), period, starts_on, now) })
      end

      private

      def save(body, period, starts_on, now)
        note = review_note_repo.save_note(period:, starts_on:, body:, now:)
        claim_photos.call(PHOTO_OWNER, note.id, note.body)
        note
      end
    end
  end
end
