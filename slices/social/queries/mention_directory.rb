# frozen_string_literal: true

module Social
  module Queries
    class MentionDirectory
      include Deps[person_repo: "repos.person_repo"]

      def call(texts)
        keys = Social::Mentions.keys(texts)

        Social::Mentions.new(keys.empty? ? [] : person_repo.by_keys(keys))
      end
    end
  end
end
