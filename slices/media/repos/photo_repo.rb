# frozen_string_literal: true

module Media
  module Repos
    class PhotoRepo < Blog::DB::Repo
      commands :create

      def claim(owner, owner_id, keys)
        photo_claims.for_owners(owner, owner_id).delete
        ids = keys.empty? ? Blog::Constants::EMPTY_ARRAY : photos.with_keys(keys).lock(mode: :share).pluck(:id)
        claims = ids.map { { owner:, owner_id:, photo_id: it } }
        photo_claims.command(:create, result: :many).call(claims) unless claims.empty?

        ids
      end

      def delete_unclaimed(id)
        photos.by_pk(id).lock.one
        photos.unclaimed.by_pk(id).delete
      end

      def release(owner, owner_ids)
        claims = photo_claims.for_owners(owner, owner_ids)
        released = photos.where(id: claims.pluck(:photo_id)).to_a
        claims.delete

        released
      end

      def unclaimed_before(at) = photos.unclaimed.uploaded_before(at).to_a
    end
  end
end
