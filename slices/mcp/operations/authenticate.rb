# frozen_string_literal: true

module MCP
  module Operations
    class Authenticate < Blog::Operation
      BEARER = /\ABearer +(?<token>\S+)\z/i
      INVALID_TOKEN = "invalid_token"
      NO_RESOURCE = "the access token names no resource"
      NO_TOKEN = "this endpoint takes a bearer access token"
      REJECT = :reject
      UNKNOWN_CLIENT = "the client this token belongs to is no longer connected"
      UNUSABLE_TOKEN = "the access token is unknown, expired or revoked"
      WRONG_RESOURCE = "the access token was issued for another resource"

      include Deps[client_repo: "repos.oauth_client_repo", token_repo: "repos.oauth_token_repo"]

      def call(authorization, issuer:)
        value = step read(authorization)
        token = step find(value)
        step check_client(token)
        step check_resource(token, issuer)
        client_repo.touch_last_used(token.oauth_client_id)
        token
      end

      private

      def check_client(token)
        return Success(token) if client_repo.connected_by_id(token.oauth_client_id)

        refuse(UNKNOWN_CLIENT)
      end

      def check_resource(token, issuer)
        return refuse(NO_RESOURCE) if token.resource.nil?
        return Success(token) if OAuth::Resource.ours?(token.resource, issuer)

        refuse(WRONG_RESOURCE)
      end

      def find(value)
        token = token_repo.by_token(value, type: Repos::OAuthTokenRepo::ACCESS)
        return refuse(UNUSABLE_TOKEN) if token.nil? || token.revoked_at || token.expires_at <= Time.now

        Success(token)
      end

      def read(authorization)
        match = BEARER.match(authorization.to_s)
        return Failure([REJECT, { error_description: NO_TOKEN }]) if match.nil?

        Success(match[:token])
      end

      def refuse(description) = Failure([REJECT, { error: INVALID_TOKEN, error_description: description }])
    end
  end
end
