# frozen_string_literal: true

module Media
  module Operations
    class ClaimPhotos
      include Deps[photo_mutations: "repos.photo_mutations"]

      def call(owner, owner_id, *texts)
        keys = texts.compact.flat_map { it.scan(Blog::Types::PHOTO_REFERENCE) }.flatten.uniq

        photo_mutations.transaction { photo_mutations.claim(Blog::Types::PhotoOwner[owner], owner_id, keys) }
      end
    end
  end
end
