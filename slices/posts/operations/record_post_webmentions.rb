# frozen_string_literal: true

module Posts
  module Operations
    class RecordPostWebmentions
      include Deps[post_mutations: "repos.post_mutations"]

      def call(id, targets:, unsent: []) = post_mutations.record_webmentions(id, targets:, unsent:)
    end
  end
end
