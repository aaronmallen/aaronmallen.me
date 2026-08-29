# frozen_string_literal: true

module Posts
  module Operations
    class RecordPostWebmentions
      include Deps[post_repo: "repos.post_repo"]

      def call(id, targets:) = post_repo.update(id, webmention_targets: targets)
    end
  end
end
