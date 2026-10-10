# frozen_string_literal: true

module Social
  module Operations
    class WakeWebmention < Blog::Operation
      include Deps[webmention_mutations: "repos.webmention_mutations", webmention_queries: "repos.webmention_queries"]

      def call(id, now: Time.now)
        webmention = step found(webmention_queries.by_id(id))
        step snoozed(webmention, now)

        webmention_mutations.snooze(id, now)
      end
    end
  end
end
