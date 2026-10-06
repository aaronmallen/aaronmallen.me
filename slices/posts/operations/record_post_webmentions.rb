# frozen_string_literal: true

module Posts
  module Operations
    class RecordPostWebmentions
      include Deps[post_repo: "repos.post_repo"]

      def call(id, targets:, unsent: [])
        post_repo.update(id, webmention_targets: targets, unsent_webmention_targets: unsent)
      end
    end
  end
end
