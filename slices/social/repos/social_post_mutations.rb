# frozen_string_literal: true

module Social
  module Repos
    class SocialPostMutations < Blog::DB::Repo
      root :social_posts

      stamped_commands :create, :update
      commands delete: :by_pk

      def claim_delivery(social_post_id, connection, due_by:, stale_before:)
        transaction do
          next unless lock_due(social_post_id, due_by)

          social_post_deliveries.claim(social_post_id:, **account(connection), stale_before:)
        end
      end

      def create_with_parts(parts:, photos: nil, **attrs)
        social_post = transaction do
          created = create(**attrs)
          write_parts(created.id, parts, photos)
          created
        end

        by_id(social_post.id)
      end

      def delete_unposted(id)
        transaction { lock_unclaimed(id) ? unclaimed(id).delete : 0 }
      end

      def lock_editable(id) = unposted(id).lock.one

      def mark_posted(id, at: Time.now) = social_posts.mark_posted(id, at:)

      def mark_unsendable(social_post, due_by:)
        transaction do
          next unless lock_due(social_post.id, due_by)

          social_post.targets.each do |network|
            social_post_deliveries.record(social_post_id: social_post.id, connection_id: nil, network:,
                                          error: "No #{network} account is connected", failed: true)
          end
          mark_posted(social_post.id)
        end
      end

      def record_delivery(social_post_id, connection, **attrs)
        social_post_deliveries.record(social_post_id:, **account(connection), **attrs)
      end

      def record_engagement(id, **counts) = social_post_deliveries.by_pk(id).stamped(:update).call(**counts)

      def replace_parts(id, parts)
        transaction do
          next unless lock_unclaimed(id)

          write_parts(id, parts)
          by_id(id)
        end
      end

      def update_with_parts(id, parts:, photos: nil, **attrs)
        transaction do
          next unless lock_unclaimed(id)

          update(id, **attrs)
          write_parts(id, parts, photos)
          by_id(id)
        end
      end

      private

      def account(connection) = { connection_id: connection.id, network: connection.provider }

      def by_id(id) = social_posts.combine(:parts, :deliveries).by_pk(id).one

      def lock_due(id, time) = social_posts.due_at(time).by_pk(id).lock(mode: :share).one

      def lock_unclaimed(id) = unposted(id).lock.one && unclaimed(id).exist?

      def unclaimed(id) = unposted(id).unclaimed

      def unposted(id) = social_posts.by_pk(id).unposted

      def write_parts(social_post_id, parts, photos = nil)
        social_post_parts.write(social_post_id, parts)
        write_photos(social_post_id, photos) if photos
      end

      def write_photos(social_post_id, photos)
        part_ids = social_post_parts.for_social_post(social_post_id).to_a.to_h { [it.position, it.id] }
        social_post_photos.write(part_ids, photos)
      end
    end
  end
end
