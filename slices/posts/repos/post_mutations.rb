# frozen_string_literal: true

module Posts
  module Repos
    class PostMutations < Blog::DB::Repo
      root :posts

      stamped_commands :create, :update
      commands delete: :by_pk

      def add_tag(id, name)
        update(id, {}) unless post_tags.tag(id, [name], tags).empty?
      end

      def by_id_for_update(id) = posts.by_pk(id).lock.one

      def hold_follow_up(**) = held_post_follow_ups.hold(**)

      def publish(id, at:) = posts.by_pk(id).unpublished.publish(at).first

      def publish_due(id, at:) = posts.by_pk(id).due_at(at).publish(at).first

      def release_follow_up(id) = held_post_follow_ups.by_pk(id).delete

      def replace_tags(id, names) = post_tags.retag(id, names, tags)
    end
  end
end
