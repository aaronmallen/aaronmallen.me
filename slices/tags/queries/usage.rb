# frozen_string_literal: true

module Tags
  module Queries
    class Usage
      include Deps[tag_repo: "repos.tag_repo"]

      def call = tag_repo.usage
    end
  end
end
