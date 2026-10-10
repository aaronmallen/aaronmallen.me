# frozen_string_literal: true

module API
  module Operations
    class MintToken < Blog::Operation
      FIELDS = %i[name scopes expires_on].freeze

      include Deps[contract: "contracts.token_contract", api_token_mutations: "repos.api_token_mutations"]

      def call(params)
        fields = step validate(params)
        value = Blog::Types::NewSecret[]

        { token: api_token_mutations.mint(token: value, **stored(fields)), value: }
      end

      private

      def stored(fields)
        {
          name: fields[:name],
          scopes: fields.fetch(:scopes, Blog::Types::OAuthScope.values),
          expires_at: fields[:expires_on]&.then { Blog::TimeZone.day_start(it) },
        }
      end

      def validate(params) = validated(contract.call(params.slice(*FIELDS)))
    end
  end
end
