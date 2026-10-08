# frozen_string_literal: true

module Social
  module Structs
    PartKey = Data.define(:network, :part) do
      def to_s = "social-post-#{part.social_post_id}-#{network}-#{part.position}"
    end
  end
end
