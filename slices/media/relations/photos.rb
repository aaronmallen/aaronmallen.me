# frozen_string_literal: true

module Media
  module Relations
    class Photos < Blog::DB::Relation
      schema :photos, infer: true

      def unclaimed = exclude(id: dataset.db[:photo_claims].select(:photo_id))

      def uploaded_before(at) = where { created_at < at }

      def with_keys(keys) = where(key: keys)
    end
  end
end
