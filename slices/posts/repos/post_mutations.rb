# frozen_string_literal: true

module Posts
  module Repos
    class PostMutations < DB::Repo
      TAG_SCOPE = Blog::Types::TagScope["public"]

      root :posts

      stamped_commands :create, :update
      commands delete: :by_pk

      def add_tag(id, name)
        tag_id = tags.claim([name], scope: TAG_SCOPE).fetch(name)
        return if tagged?(id, tag_id)

        post_tags.add(id, [tag_id])
        update(id, {})
      end

      def by_id_for_update(id) = posts.by_pk(id).lock.one

      def hold_follow_up(**) = held_post_follow_ups.hold(**)

      def publish(id, at:) = posts.by_pk(id).unpublished.publish(at).first

      def publish_due(id, at:) = posts.by_pk(id).due_at(at).publish(at).first

      def release_follow_up(id) = held_post_follow_ups.by_pk(id).delete

      def replace_tags(id, names) = post_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))

      private

      def tagged?(id, tag_id) = post_tags.for_owner(id).where(tag_id:).exist?
    end
  end
end
