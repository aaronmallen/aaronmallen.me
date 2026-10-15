# frozen_string_literal: true

module Shares
  module Operations
    class CheckShortLinks
      include Deps[
        "operations.check_link",
        link_check_mutations: "repos.short_link_check_mutations",
        short_link_queries: "repos.short_link_queries",
      ]

      def again(id, at: Time.now)
        link = short_link_queries.find(id)
        check([link], at) if link
      end

      def call(at: Time.now) = check(short_link_queries.destinations, at)

      private

      def check(links, at)
        link_check_mutations.forget_stale
        links.each { record(it.id, it.destination, at) }
      end

      def record(short_link_id, url, at)
        link_check_mutations.record(short_link_id:, url:, reason: check_link.call(url), at:)
      end
    end
  end
end
