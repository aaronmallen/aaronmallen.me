# frozen_string_literal: true

module Shares
  module Operations
    class SetShortLinkTitle < Blog::Operation
      include Deps[
        contract: "contracts.short_link_contract", short_link_mutations: "repos.short_link_mutations",
        short_link_queries: "repos.short_link_queries",
      ]

      def call(id, params)
        link = step found(short_link_queries.find(id))
        fields = step validated(contract.call(title: params[:title]))

        transaction { short_link_mutations.update(link.id, title: fields[:title]) }
        short_link_queries.find(link.id)
      end
    end
  end
end
