# frozen_string_literal: true

module Shares
  module Operations
    class AddSharesToGroup < Blog::Operation
      include Deps[
        group_mutations: "repos.share_group_mutations",
        group_queries: "repos.share_group_queries",
        share_queries: "repos.share_queries",
      ]

      def call(id, ids)
        group = step found(group_queries.find(id))
        shares = step picked(ids)

        transaction { shares.each { group_mutations.join(it.id, group.id, it.short_code_id) } }
        group_queries.find(group.id)
      end

      private

      def picked(ids)
        return Failure([:invalid, { ids: [Blog::Contract::BLANK] }]) if ids.empty?

        shares = ids.uniq.map { share_queries.find(it) }
        shares.all? ? Success(shares) : Failure(:not_found)
      end
    end
  end
end
