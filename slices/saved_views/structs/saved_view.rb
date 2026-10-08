# frozen_string_literal: true

module SavedViews
  module Structs
    class SavedView < Blog::DB::Struct
      def filters = Contracts::FiltersContract.new.call(screen:, filters: self[:filters]).to_h[:filters]
    end
  end
end
