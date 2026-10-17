# frozen_string_literal: true

module Projects
  module Repos
    class ProjectQueries < Blog::DB::Repo
      def archived = with_tags.archived.newest_archived_first.to_a

      def by_id(id) = with_tags.by_pk(id).one

      def by_ids(ids) = projects.where(id: ids).in_name_order.to_a

      def by_name = projects.in_name_order.to_a

      def by_tag(tag) = with_tags.tagged(tag).in_order.to_a

      def id_by_key(key) = projects.where(Sequel.function(:lower, :key) => key.downcase).pluck(:id).first

      def ids_by_slug(slugs) = projects.slugged(slugs)

      def live = with_tags.live.in_order.to_a

      def live_by_name = projects.live.in_name_order.to_a

      def live_id_by_key(key) = projects.live.where(key:).pluck(:id).first

      def name_of(id) = (projects.where(id:).pluck(:name).first if id)

      def page_by_tag(tag, page) = page.fill(projects.tagged(tag).in_order.paged(page).to_a)

      def public_archived = with_tags.in_public.archived.by_stars.to_a

      def public_board(slug)
        id = projects.in_public.with_board.slugged([slug]).first
        projects.by_pk(id).one if id
      end

      def public_board_reached?(ids)
        projects.in_public.with_board.where(Sequel.|({ id: ids }, Sequel.~(repo: nil))).exist?
      end

      def public_boards(ids) = projects.in_public.with_board.where(id: ids).in_order.to_a

      def public_by_tag(tag) = with_tags.in_public.live.tagged(tag).in_order.to_a

      def public_grid(limit = nil) = with_tags.in_public.live.by_stars.limit(limit).to_a

      def public_tag?(tag) = projects.in_public.live.tagged(tag).select(:id).exist?

      def public_tag_names
        tagged = project_tags.where(project_id: projects.in_public.live.select(:id).dataset).select(:tag_id)

        tags.where(id: tagged.dataset).pluck(:name)
      end

      def sitemap_boards = projects.in_public.with_board.in_order.to_a

      def slugs_besides(id) = projects.exclude(id:).slugs

      def tracked = with_tags.tracked.in_order.to_a

      private

      def with_tags = projects.combine(:tags)
    end
  end
end
