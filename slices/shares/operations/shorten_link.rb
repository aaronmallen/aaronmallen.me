# frozen_string_literal: true

module Shares
  module Operations
    class ShortenLink < Blog::Operation
      include Deps[
        create_short_link: "operations.create_short_link", short_link_mutations: "repos.short_link_mutations",
        short_link_queries: "repos.short_link_queries",
      ]

      def call(destination)
        transaction do
          short_link_mutations.lock_destination(destination)
          short_link_queries.by_destination(destination) || step(create_short_link.call(destination:))
        end
      end
    end
  end
end
