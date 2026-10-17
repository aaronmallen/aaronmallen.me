# frozen_string_literal: true

module Shares
  module Jobs
    class QueueHeldTitleFetches < Blog::ScheduledJob
      include Deps[short_link_mutations: "repos.short_link_mutations", short_link_queries: "repos.short_link_queries"]

      def perform = short_link_queries.held_fetches.each { queue(it) }

      private

      def queue(held)
        FetchShortLinkTitle.perform_async(held.short_link_id)
        short_link_mutations.release_title_fetch(held.id)
      end
    end
  end
end
