# frozen_string_literal: true

require "rack/utils"

module MCP
  module Operations
    class IssueToken < Operation
      INVALID_CLIENT = "invalid_client"
      INVALID_GRANT = "invalid_grant"
      REJECT = :reject
      UNKNOWN_CLIENT = "client_id names no connected client"
      UNKNOWN_GRANT_TYPE = "grant_type must be authorization_code or refresh_token"
      UNSUPPORTED_GRANT_TYPE = "unsupported_grant_type"
      UNUSABLE_CODE = "the authorization code is unknown, expired or already used"
      UNUSABLE_REDIRECT_URI = "redirect_uri must match the one the code was issued to"
      UNUSABLE_REFRESH_TOKEN = "the refresh token is unknown, expired or already used"
      UNUSABLE_VERIFIER = "code_verifier does not match the code_challenge"
      REFUSALS = {
        grant_type: [UNSUPPORTED_GRANT_TYPE, UNKNOWN_GRANT_TYPE],
        code: [INVALID_GRANT, UNUSABLE_CODE],
        refresh_token: [INVALID_GRANT, UNUSABLE_REFRESH_TOKEN],
        redirect_uri: [INVALID_GRANT, UNUSABLE_REDIRECT_URI],
        code_verifier: [INVALID_GRANT, UNUSABLE_VERIFIER],
      }.freeze

      include Deps[
        "operations.derive_code_challenge",
        "operations.issue_tokens",
        "repos.oauth_client_queries",
        "repos.oauth_code_mutations",
        "repos.oauth_code_queries",
        "repos.oauth_token_mutations",
        "repos.oauth_token_queries",
        contract: "contracts.token_request_contract",
      ]

      def call(params)
        request = step validate(params)

        if request[:grant_type] == Contracts::TokenRequestContract::AUTHORIZATION_CODE
          exchange_code(request, params[:client_id])
        else
          rotate(request, params[:client_id])
        end
      end

      private

      def check_client(record, client_id)
        client = oauth_client_queries.connected_by_id(record.oauth_client_id)
        return Success(client) if client && client.client_id == client_id

        Failure([REJECT, { error: INVALID_CLIENT, error_description: UNKNOWN_CLIENT }])
      end

      def check_grant(code, request)
        return refuse(UNUSABLE_REDIRECT_URI) unless redirect_uri_matches?(code, request[:redirect_uri])
        return refuse(UNUSABLE_VERIFIER) unless verifier_matches?(code, request[:code_verifier])

        Success(code)
      end

      def exchange_code(request, client_id)
        code = step find_code(request[:code])
        client = step check_client(code, client_id)
        step check_grant(code, request)
        step settle(client, code, UNUSABLE_CODE) { oauth_code_mutations.burn(code.id) }
      end

      def find_code(value)
        code = oauth_code_queries.by_code(value)
        return refuse(UNUSABLE_CODE) if code.nil?
        return replay(code.oauth_client_id, UNUSABLE_CODE) if code.used_at
        return refuse(UNUSABLE_CODE) if code.expires_at <= Time.now

        Success(code)
      end

      def find_token(value)
        token = oauth_token_queries.by_token(value, type: Blog::Types::OAuthTokenType["refresh"])
        return refuse(UNUSABLE_REFRESH_TOKEN) if token.nil?
        return replay(token.oauth_client_id, UNUSABLE_REFRESH_TOKEN) if token.revoked_at
        return refuse(UNUSABLE_REFRESH_TOKEN) if token.expires_at <= Time.now

        Success(token)
      end

      def grant(client, record)
        issue_tokens.call(oauth_client_id: client.id, resource: record.resource, scopes: record.scopes)
      end

      def redirect_uri_matches?(code, redirect_uri)
        redirect_uri.nil? ? !code.redirect_uri_sent : redirect_uri == code.redirect_uri
      end

      def refuse(description, error: INVALID_GRANT) = Failure([REJECT, { error:, error_description: description }])

      def replay(oauth_client_id, description)
        oauth_token_mutations.revoke_for_client(oauth_client_id)
        refuse(description)
      end

      def rotate(request, client_id)
        token = step find_token(request[:refresh_token])
        client = step check_client(token, client_id)
        step settle(client, token, UNUSABLE_REFRESH_TOKEN) { oauth_token_mutations.revoke(token.id) }
      end

      def settle(client, record, description)
        granted = transaction do
          grant(client, record) if oauth_client_queries.connected_by_id_for_update(client.id) && yield
        end

        granted || replay(record.oauth_client_id, description)
      end

      def validate(params)
        result = contract.call(params)
        return Success(result.to_h) if result.success?

        error, description = REFUSALS.find { |field, _| result.error?(field) }.last
        refuse(description, error:)
      end

      def verifier_matches?(code, verifier)
        Rack::Utils.secure_compare(code.code_challenge, derive_code_challenge.call(verifier))
      end
    end
  end
end
