# frozen_string_literal: true

module SavedViews
  module Repos
    class SavedViewQueries < Blog::DB::Repo
      def all(screen: nil) = (screen ? saved_views.on_screen(screen) : saved_views).in_list_order.to_a

      def by_id(id) = saved_views.by_pk(id).one

      def screen_filters(screen) = Contracts::FiltersContract.names(screen)
    end
  end
end
