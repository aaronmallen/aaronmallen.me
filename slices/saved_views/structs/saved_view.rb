# frozen_string_literal: true

module SavedViews
  module Structs
    class SavedView < Blog::DB::Struct
      def filters = Filters.keep(screen, self[:filters])
    end
  end
end
