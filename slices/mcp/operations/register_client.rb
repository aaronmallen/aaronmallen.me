# frozen_string_literal: true

require "securerandom"

module MCP
  module Operations
    class RegisterClient < Operation
      INVALID_METADATA = "invalid_client_metadata"
      INVALID_REDIRECT_URI = "invalid_redirect_uri"
      NOT_AN_OBJECT = "the request body must be a JSON object"
      REJECT = :reject
      THROTTLED = :throttled
      UNUSABLE_METADATA =
        "client_name may hold up to #{Contracts::ClientRegistrationContract::MAX_NAME} characters and " \
        "client_uri and logo_uri up to #{Contracts::ClientRegistrationContract::MAX_URI}, " \
        "with no control character in any of them".freeze
      UNUSABLE_REDIRECT_URIS =
        "redirect_uris must list 1 to #{Contracts::ClientRegistrationContract::MAX_REDIRECT_URIS} " \
        "https or loopback http URIs, none of them carrying a fragment".freeze

      include Deps[
        "repos.oauth_client_mutations",
        "repos.oauth_client_queries",
        "settings",
        contract: "contracts.client_registration_contract",
      ]

      def call(payload, visitor_hashes:)
        step within_limit(visitor_hashes)
        attributes = step validate(payload)

        document(step(claim(attributes, visitor_hashes:)))
      end

      private

      def claim(attributes, visitor_hashes:)
        client = oauth_client_mutations.claim(
          client_id: SecureRandom.uuid,
          grant_types: Blog::Types::OAuthGrantType.values,
          response_types: Blog::Types::OAuthResponseType.values,
          token_endpoint_auth_method: Blog::Types::OAuthTokenAuthMethod["none"],
          **attributes,
          visitor_hashes:,
          limit:,
          total_limit:,
          since: window_opened_at,
        )

        client ? Success(client) : Failure(THROTTLED)
      end

      def document(client)
        {
          client_id: client.client_id,
          client_id_issued_at: client.created_at.to_i,
          client_name: client.client_name,
          client_uri: client.client_uri,
          grant_types: client.grant_types,
          logo_uri: client.logo_uri,
          redirect_uris: client.redirect_uris,
          response_types: client.response_types,
          token_endpoint_auth_method: client.token_endpoint_auth_method,
        }.compact
      end

      def limit = settings.client_registration[:throttle_limit]

      def refuse(error, description) = Failure([REJECT, { error:, error_description: description }])

      def total_limit = settings.client_registration[:total_throttle_limit]

      def validate(payload)
        return refuse(INVALID_METADATA, NOT_AN_OBJECT) unless payload.is_a?(Hash)

        result = contract.call(payload)
        return Success(result.to_h) if result.success?
        return refuse(INVALID_REDIRECT_URI, UNUSABLE_REDIRECT_URIS) if result.error?(:redirect_uris)

        refuse(INVALID_METADATA, UNUSABLE_METADATA)
      end

      def window_opened_at
        Time.now - (settings.client_registration[:throttle_window_minutes] * Blog::Helpers::Figures::MINUTE)
      end

      def within_limit(visitor_hashes)
        since = window_opened_at
        under = oauth_client_queries.count_from_visitor_since(visitor_hashes, since) < limit &&
                oauth_client_queries.count_since(since) < total_limit

        under ? Success(visitor_hashes) : Failure(THROTTLED)
      end
    end
  end
end
