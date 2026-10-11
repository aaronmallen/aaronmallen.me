# frozen_string_literal: true

module Shares
  module Operations
    class SetShareAltText < Blog::Operation
      include Deps[
        contract: "contracts.share_contract", share_mutations: "repos.share_mutations",
        share_queries: "repos.share_queries",
      ]

      def call(id, params)
        share = step found(share_queries.find(id))
        fields = step validated(contract.call(alt_text: params[:alt_text]))

        transaction { share_mutations.update(share.id, alt_text: fields[:alt_text]) }
        share_queries.find(share.id)
      end
    end
  end
end
