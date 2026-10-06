# frozen_string_literal: true

module Decisions
  module Structs
    class DecisionTimeline < Blog::DB::Struct
      def comment? = kind == Blog::Types::DecisionTimelineKind["comment"]

      def synced? = false
    end
  end
end
