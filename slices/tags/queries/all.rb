# frozen_string_literal: true

module Tags
  module Queries
    class All
      include Deps[tag_repo: "repos.tag_repo"]

      def call = tag_repo.all
    end
  end
end
