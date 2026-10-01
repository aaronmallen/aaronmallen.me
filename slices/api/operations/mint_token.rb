# frozen_string_literal: true

module API
  module Operations
    class MintToken < Blog::Operation
      include Deps[contract: "contracts.token_contract", token_repo: "repos.api_token_repo"]

      def call(params)
        fields = step validate(params)
        value = Token.generate

        { token: token_repo.mint(token: value, name: fields[:name]), value: }
      end

      private

      def validate(params) = validated(contract.call(name: params[:name]))
    end
  end
end
