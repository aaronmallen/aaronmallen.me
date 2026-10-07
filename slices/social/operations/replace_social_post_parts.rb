# frozen_string_literal: true

module Social
  module Operations
    class ReplaceSocialPostParts
      include Deps[social_post_mutations: "repos.social_post_mutations"]

      def call(id, parts) = social_post_mutations.replace_parts(id, parts)
    end
  end
end
