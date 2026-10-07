# frozen_string_literal: true

module Projects
  module Repos
    class ProjectRepo < DB::Repo
      TAG_SCOPE = Blog::Types::TagScope["public"]

      stamped_commands :create, :update

      def archived = with_tags.archived.newest_archived_first.to_a

      def by_id(id) = with_tags.by_pk(id).one

      def by_tag(tag) = with_tags.tagged(tag).in_order.to_a

      def live = with_tags.live.in_order.to_a

      def public_archived = with_tags.in_public.archived.by_stars.to_a

      def public_by_tag(tag) = with_tags.in_public.live.tagged(tag).in_order.to_a

      def public_grid(limit = nil) = with_tags.in_public.live.by_stars.limit(limit).to_a

      def replace_tags(id, names) = project_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))

      def tracked = with_tags.tracked.in_order.to_a

      private

      def with_tags = projects.combine(:tags)
    end
  end
end
