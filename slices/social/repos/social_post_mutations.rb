# frozen_string_literal: true

module Social
  module Repos
    class SocialPostMutations < DB::Repo
      root :social_posts

      stamped_commands :create, :update
      commands delete: :by_pk

      def claim_delivery(social_post_id, connection, due_by:, stale_before:)
        transaction do
          next unless lock_due(social_post_id, due_by)

          social_post_deliveries.claim(social_post_id:, **account(connection), stale_before:)
        end
      end

      def create_with_parts(parts:, **attrs)
        social_post = transaction do
          created = create(**attrs)
          insert_parts(created.id, parts)
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

          social_post_parts.for_social_post(id).delete
          insert_parts(id, parts)
          by_id(id)
        end
      end

      def update_with_parts(id, parts:, **attrs)
        transaction do
          next unless lock_unclaimed(id)

          update(id, **attrs)
          social_post_parts.for_social_post(id).delete
          insert_parts(id, parts)
          by_id(id)
        end
      end

      private

      def account(connection) = { connection_id: connection.id, network: connection.provider }

      def by_id(id) = social_posts.combine(:parts, :deliveries).by_pk(id).one

      def insert_parts(social_post_id, parts)
        rows = parts.each_with_index.map { |body, index| { social_post_id:, position: index + 1, body: } }

        social_post_parts.stamped(:create, result: :many).call(rows)
      end

      def lock_due(id, time) = social_posts.due_at(time).by_pk(id).lock(mode: :share).one

      def lock_unclaimed(id) = unposted(id).lock.one && unclaimed(id).exist?

      def unclaimed(id) = unposted(id).unclaimed

      def unposted(id) = social_posts.by_pk(id).unposted
    end
  end
end
