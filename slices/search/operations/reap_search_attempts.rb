# frozen_string_literal: true

module Search
  module Operations
    class ReapSearchAttempts
      include Deps["settings", attempt_mutations: "repos.search_attempt_mutations"]

      def call(at: Time.now) = attempt_mutations.delete_before(Blog::Throttle.new(settings.search).since(at))
    end
  end
end
