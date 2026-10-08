# frozen_string_literal: true

module Social
  module Structs
    PartLength = Data.define(:network, :part, :count, :limit, :over) do
      def counted = { count:, limit: }
    end
  end
end
