# frozen_string_literal: true

module Media
  module Relations
    class Photos < Blog::DB::Relation
      POST = Blog::Types::PhotoOwner["post"]
      PUBLISHED = Blog::Types::PostStatus["published"]

      schema :photos, infer: true

      def published
        posts = dataset.db[:posts].where(status: PUBLISHED).select(:id)
        where(id: dataset.db[:photo_claims].where(owner: POST, owner_id: posts).select(:photo_id))
      end

      def unclaimed = exclude(id: dataset.db[:photo_claims].select(:photo_id))

      def uploaded_before(at) = where { created_at < at }

      def with_keys(keys) = where(key: keys)
    end
  end
end
