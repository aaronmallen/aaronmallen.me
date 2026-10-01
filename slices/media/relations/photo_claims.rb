# frozen_string_literal: true

module Media
  module Relations
    class PhotoClaims < Blog::DB::Relation
      schema :photo_claims, infer: true

      def for_owners(owner, owner_ids) = where(owner:, owner_id: owner_ids)
    end
  end
end
