# frozen_string_literal: true

module Social
  PartKey = Data.define(:network, :part) do
    def to_s = "social-post-#{part.social_post_id}-#{network}-#{part.position}"
  end
end
