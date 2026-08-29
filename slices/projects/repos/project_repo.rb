# frozen_string_literal: true

module Projects
  module Repos
    class ProjectRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def archived = with_tags.archived.newest_archived_first.to_a

      def by_id(id) = with_tags.by_pk(id).one

      def live = with_tags.live.in_order.to_a

      def next_position = projects.last_position + 1

      def public_by_tag(tag) = with_tags.live.tagged(tag).featured_first.to_a

      def public_grid(limit = nil) = with_tags.live.featured_first.limit(limit).to_a

      def replace_tags(id, names) = project_tags.replace(id, tags.claim(names).values_at(*names))

      def swap_positions(one, two)
        transaction do
          update(one.id, position: next_position)
          update(two.id, position: one.position)
          update(one.id, position: two.position)
        end
      end

      def tracked = with_tags.tracked.in_order.to_a

      private

      def with_tags = projects.combine(:tags)
    end
  end
end
