# frozen_string_literal: true

module SavedViews
  module Repos
    class SavedViewRepo < Blog::DB::Repo
      stamped_commands :create, :update
      commands delete: :by_pk

      def all(screen: nil) = (screen ? saved_views.on_screen(screen) : saved_views).in_list_order.to_a

      def by_id(id) = saved_views.by_pk(id).one
    end
  end
end
