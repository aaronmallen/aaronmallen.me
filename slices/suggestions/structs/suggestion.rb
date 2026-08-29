# frozen_string_literal: true

module Suggestions
  module Structs
    class Suggestion < Blog::DB::Struct
      def edits = suggestion_edits

      def open_edits = edits.select(&:open?)
    end
  end
end
