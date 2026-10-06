# frozen_string_literal: true

module Projects
  module Repos
    class ProjectRepo < Blog::DB::Repo
      TAG_SCOPE = Blog::Types::TagScope["public"]

      stamped_commands :create, :update

      def append(**fields)
        transaction do
          projects.lock_positions_until_commit
          create(**fields, position: next_position)
        end
      end

      def archived = with_tags.archived.newest_archived_first.to_a

      def by_id(id) = with_tags.by_pk(id).one

      def live = with_tags.live.in_order.to_a

      def public_by_tag(tag) = with_tags.live.tagged(tag).featured_first.to_a

      def public_grid(limit = nil) = with_tags.live.featured_first.limit(limit).to_a

      def replace_tags(id, names) = project_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))

      def swap_positions(one, two)
        transaction do
          projects.lock_positions_until_commit
          update(one.id, position: next_position)
          update(two.id, position: one.position)
          update(one.id, position: two.position)
        end
      end

      def tracked = with_tags.tracked.in_order.to_a

      private

      def next_position = projects.last_position + 1

      def with_tags = projects.combine(:tags)
    end
  end
end
