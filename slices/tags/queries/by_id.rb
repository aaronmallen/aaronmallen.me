# frozen_string_literal: true

module Tags
  module Queries
    class ById
      include Deps[tag_repo: "repos.tag_repo"]

      def call(id, scope:) = tag_repo.find_in(scope, id)
    end
  end
end
