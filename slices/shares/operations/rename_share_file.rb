# frozen_string_literal: true

module Shares
  module Operations
    class RenameShareFile < Blog::Operation
      include Deps[
        contract: "contracts.share_contract",
        group_mutations: "repos.share_group_mutations",
        group_queries: "repos.share_group_queries",
      ]

      def call(id, params)
        file = step found(group_queries.file(id))
        fields = step validated(contract.call(filename: params[:filename]))

        transaction { group_mutations.update_file(file.id, filename: fields[:filename]) }
        group_queries.file(file.id)
      end
    end
  end
end
