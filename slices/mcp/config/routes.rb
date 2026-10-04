# frozen_string_literal: true

module MCP
  class Routes < Hanami::Routes
    PROTECTED_RESOURCE = "/.well-known/oauth-protected-resource"

    get "/.well-known/oauth-authorization-server", to: "metadata.authorization_server"
    get PROTECTED_RESOURCE, to: "metadata.protected_resource"
    get "#{PROTECTED_RESOURCE}#{Slice::RESOURCE_PATH}", to: "metadata.protected_resource", as: :resource_metadata

    post Slice::RESOURCE_PATH, to: "messages.create"
    options Slice::RESOURCE_PATH, to: "preflights.show"

    scope Slice::OAUTH_PREFIX do
      use(*Slice.config.actions.sessions.middleware)

      get "/authorize", to: "authorizations.new", as: :authorize
      post "/authorize", to: "authorizations.create", as: :decide
      post "/register", to: "clients.create", as: :register
      post "/token", to: "tokens.create", as: :token
      options "/token", to: "preflights.show"
    end
  end
end
