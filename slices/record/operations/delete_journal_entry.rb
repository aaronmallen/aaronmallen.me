# frozen_string_literal: true

module Record
  module Operations
    class DeleteJournalEntry < Blog::Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["journal_entry"]

      include Deps[journal_entry_repo: "repos.journal_entry_repo", release_photos: "media.operations.release_photos"]

      def call(id)
        transaction do
          step found(journal_entry_repo.delete(id))
          release_photos.call(PHOTO_OWNER, id)
          id
        end
      end
    end
  end
end
