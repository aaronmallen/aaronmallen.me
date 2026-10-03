# frozen_string_literal: true

module Decisions
  module Structs
    class Decision < Blog::DB::Struct
      def closed? = !open?

      def open? = status == Blog::Types::DecisionStatus["open"]
    end
  end
end
