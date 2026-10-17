# frozen_string_literal: true

module Shares
  module Operations
    class ChangeShortLinkCode < Blog::Operation
      include Deps[
        contract: "contracts.short_link_contract", short_link_mutations: "repos.short_link_mutations",
        short_link_queries: "repos.short_link_queries",
      ]

      def call(id, params)
        link = step found(short_link_queries.find(id))
        fields = step validated(contract.call(code: params[:code]))

        step change(link, fields[:code])
      end

      private

      def change(link, code)
        Helpers::Code.taken(short_link_mutations) do
          transaction { short_link_mutations.change_code(link.short_code_id, code) }
          Success(short_link_queries.find(link.id))
        end
      end
    end
  end
end
