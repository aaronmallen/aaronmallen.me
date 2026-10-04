# frozen_string_literal: true

module Decisions
  module Structs
    class DecisionTimeline < Blog::DB::Struct
      def comment? = kind == Blog::Types::DecisionTimelineKind["comment"]
    end
  end
end
