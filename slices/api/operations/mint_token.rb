# frozen_string_literal: true

module API
  module Operations
    class MintToken < Operation
      include Deps[contract: "contracts.token_contract", api_token_mutations: "repos.api_token_mutations"]

      def call(params)
        fields = step validate(params)
        value = Blog::Types::NewSecret[]

        { token: api_token_mutations.mint(token: value, name: fields[:name]), value: }
      end

      private

      def validate(params) = validated(contract.call(name: params[:name]))
    end
  end
end
