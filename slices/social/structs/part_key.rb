# frozen_string_literal: true

module Social
  module Structs
    PartKey = Data.define(:connection_id, :part) do
      def to_s = "social-post-#{part.social_post_id}-#{connection_id}-#{part.position}"
    end
  end
end
