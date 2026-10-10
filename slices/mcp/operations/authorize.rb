# frozen_string_literal: true

module MCP
  module Operations
    class Authorize < Blog::Operation
      ACCESS_DENIED = "access_denied"
      APPROVE = Blog::Types::OAuthDecision["approve"]
      CANCEL = Blog::Types::OAuthDecision["cancel"]
      CODE_LIFETIME = 60
      CONFIRM = :confirm
      INVALID_CLIENT = "invalid_client"
      INVALID_REQUEST = "invalid_request"
      INVALID_SCOPE = "invalid_scope"
      INVALID_TARGET = "invalid_target"
      REFUSE = :refuse
      REJECT = :reject
      SIGN_IN = :sign_in
      UNAPPROVED = "the operator did not approve this connection"
      UNKNOWN_CLIENT = "client_id names no connected client"
      UNSUPPORTED_RESPONSE_TYPE = "unsupported_response_type"
      UNUSABLE_CHALLENGE =
        "code_challenge must be 43 to 128 unreserved characters and code_challenge_method must be S256"
      UNUSABLE_REDIRECT_URI = "redirect_uri must be one this client registered"
      UNUSABLE_RESOURCE = "resource must name this server"
      UNUSABLE_RESPONSE_TYPE = "response_type must be code"
      UNUSABLE_SCOPE = "scope must be scope names split by single spaces"
      UNUSABLE_STATE = "state must hold only printable ASCII characters"
      REFUSALS = {
        response_type: [UNSUPPORTED_RESPONSE_TYPE, UNUSABLE_RESPONSE_TYPE],
        code_challenge: [INVALID_REQUEST, UNUSABLE_CHALLENGE],
        code_challenge_method: [INVALID_REQUEST, UNUSABLE_CHALLENGE],
        resource: [INVALID_TARGET, UNUSABLE_RESOURCE],
        scope: [INVALID_SCOPE, UNUSABLE_SCOPE],
        state: [INVALID_REQUEST, UNUSABLE_STATE],
      }.freeze

      include Deps[
        "operations.describe_protected_resource",
        "repos.oauth_client_queries",
        "repos.oauth_code_mutations",
        contract: "contracts.authorization_request_contract",
      ]

      def call(params, issuer:, signed_in:, decision: nil)
        client = step find_client(params[:client_id])
        redirect_uri = step find_redirect_uri(client, params[:redirect_uri])
        step check_sign_in(signed_in)
        request, callback = step check_request(params, issuer, redirect_uri)
        scopes = granted_scopes(request[:scope])
        step check_decision(decision, client, redirect_uri, scopes)
        answer(decision, callback, client:, issuer:, request:, redirect_uri:, scopes:)
      end

      private

      def answer(decision, callback, client:, issuer:, request:, redirect_uri:, scopes:)
        return callback.error(ACCESS_DENIED, UNAPPROVED) unless decision == APPROVE

        callback.granted(issue(client:, issuer:, request:, redirect_uri:, scopes:))
      end

      def check_decision(decision, client, redirect_uri, scopes)
        return Success(decision) if [APPROVE, CANCEL].include?(decision)

        Failure([CONFIRM, confirmation(client, redirect_uri, scopes)])
      end

      def check_request(params, issuer, redirect_uri)
        result = contract.call(params, issuer:)
        state = result[:state] unless result.error?(:state)
        callback = Structs::Callback.new(issuer:, redirect_uri:, state:)
        return Success([result.to_h, callback]) if result.success?

        error, description = REFUSALS.find { |field, _| result.error?(field) }.last
        Failure([REFUSE, { error:, error_description: description, url: callback.error(error, description) }])
      end

      def check_sign_in(signed_in) = signed_in ? Success(signed_in) : Failure(SIGN_IN)

      def confirmation(client, redirect_uri, scopes)
        {
          client_name: client.client_name,
          new_client: !oauth_client_queries.held_token?(client.id),
          redirect_uri:,
          registered_at: client.created_at,
          scopes:,
        }
      end

      def find_client(client_id)
        client = oauth_client_queries.connected_by_client_id(client_id) if client_id
        return Success(client) if client

        Failure([REJECT, { error: INVALID_CLIENT, error_description: UNKNOWN_CLIENT }])
      end

      def find_redirect_uri(client, redirect_uri)
        return Success(client.redirect_uris.first) if redirect_uri.nil? && client.redirect_uris.one?
        return Success(redirect_uri) if client.redirect_uris.include?(redirect_uri)

        Failure([REJECT, { error: INVALID_REQUEST, error_description: UNUSABLE_REDIRECT_URI }])
      end

      def granted_scopes(requested)
        kept = Blog::Types::OAuthScope.values & requested.to_s.split

        kept.empty? ? [Blog::Types::OAuthScope["read"]] : kept
      end

      def issue(client:, issuer:, request:, redirect_uri:, scopes:)
        Blog::Types::NewSecret[].tap do |code|
          oauth_code_mutations.issue(
            code:,
            code_challenge: request[:code_challenge],
            expires_at: Time.now + CODE_LIFETIME,
            oauth_client_id: client.id,
            redirect_uri:,
            redirect_uri_sent: !request[:redirect_uri].nil?,
            resource: request[:resource] || describe_protected_resource.call(issuer)[:resource],
            scopes:,
          )
        end
      end
    end
  end
end
