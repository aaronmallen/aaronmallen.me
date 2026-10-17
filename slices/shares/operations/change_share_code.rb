# frozen_string_literal: true

module Shares
  module Operations
    class ChangeShareCode < Blog::Operation
      include Deps[
        contract: "contracts.share_contract", share_mutations: "repos.share_mutations",
        share_queries: "repos.share_queries",
      ]

      def call(id, params)
        share = step found(share_queries.find(id))
        fields = step validate(code: params[:code])

        step change(share, fields[:code])
      end

      private

      def change(share, code)
        Helpers::Code.taken(share_mutations) do
          transaction { share_mutations.change_code(share.short_code_id, code) }
          Success(share_queries.find(share.id))
        end
      end

      def validate(form) = validated(contract.call(form))
    end
  end
end
