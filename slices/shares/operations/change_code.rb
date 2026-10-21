# frozen_string_literal: true

module Shares
  module Operations
    class ChangeCode < Blog::Operation
      include Deps[contract: "contracts.share_contract", mutations: "repos.share_mutations"]

      def call(owner, params)
        fields = step validated(contract.call(code: params[:code]))

        step change(owner, fields[:code])
      end

      private

      def change(owner, code)
        constrained(mutations, Helpers::Code::CONSTRAINTS) do
          Success(transaction { mutations.change_code(owner.short_code_id, code) })
        end
      end
    end
  end
end
