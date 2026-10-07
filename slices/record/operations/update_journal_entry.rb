# frozen_string_literal: true

module Record
  module Operations
    class UpdateJournalEntry < Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["journal_entry"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        contract: "contracts.journal_edit_contract",
        journal_entry_mutations: "repos.journal_entry_mutations",
        journal_entry_queries: "repos.journal_entry_queries",
      ]

      def call(id, params)
        step find(id)
        attributes = step validate(params)
        step persist(id, attributes)
      end

      private

      def find(id) = found(journal_entry_queries.by_id(id) && id)

      def form(params) = { body: params[:body], tags: params[:tags] }

      def persist(id, attributes)
        transaction do
          journal_entry_mutations.update(id, **attributes.except(:tags))
          journal_entry_mutations.replace_tags(id, attributes.fetch(:tags))
          claim_photos.call(PHOTO_OWNER, id, attributes[:body])
        end

        Success(journal_entry_queries.by_id(id))
      end

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
