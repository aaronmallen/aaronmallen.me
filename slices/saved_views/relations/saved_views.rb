# frozen_string_literal: true

module SavedViews
  module Relations
    class SavedViews < Blog::DB::Relation
      schema :saved_views, infer: true

      def in_list_order = order(self[:screen], self[:name], self[:id])

      def on_screen(screen) = where(screen:)
    end
  end
end
