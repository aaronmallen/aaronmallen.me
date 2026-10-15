# frozen_string_literal: true

module Shares
  module Operations
    class NameShareGroup < Blog::Operation
      include Deps[
        contract: "contracts.share_contract",
        group_mutations: "repos.share_group_mutations",
        group_queries: "repos.share_group_queries",
      ]

      def call(id, params)
        group = step found(group_queries.find(id))
        fields = step validated(contract.call(name: params[:name]))

        transaction { group_mutations.name(group.id, fields[:name]) }
        group_queries.find(group.id)
      end
    end
  end
end
