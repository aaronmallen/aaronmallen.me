# frozen_string_literal: true

module SavedViews
  module Repos
    class SavedViewRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }
      commands delete: :by_pk

      def all(screen: nil) = (screen ? saved_views.on_screen(screen) : saved_views).in_list_order.to_a

      def by_id(id) = saved_views.by_pk(id).one
    end
  end
end
