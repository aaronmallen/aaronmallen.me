# frozen_string_literal: true

module Shares
  module Operations
    class DeleteShortLink < Blog::Operation
      include Deps[short_link_mutations: "repos.short_link_mutations", short_link_queries: "repos.short_link_queries"]

      def call(id)
        link = step found(short_link_queries.find(id))

        transaction { short_link_mutations.delete(link.short_code_id) }
        link
      end
    end
  end
end
