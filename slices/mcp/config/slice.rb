# frozen_string_literal: true

require "blog/extensions"
require "mcp"

Blog::Extensions.pin(
  MCP::Server,
  gem: "mcp",
  version: "1.7.0",
  reason: "MCP::Protocol::ScopedServer overrides MCP::Server's private call_tool and list_tools",
  upstream: nil,
)

module MCP
  class Slice < Hanami::Slice
    OAUTH_PREFIX = "/oauth"
    RESOURCE_PATH = "/mcp"

    config.no_auto_register_paths += %w[prompts tools]

    config.shared_app_component_keys += %w[assets honeybadger.agent]

    config.actions.content_security_policy[:frame_ancestors] = "'none'"
    config.actions.content_security_policy[:form_action] = "'self' https: http:"

    config.actions.csrf_protection = false

    config.actions.sessions = Blog::SessionCookie.store

    import keys: %w[auth.session_reader], from: :admin

    import from: :api

    import keys: %w[operations.hash_visitor], from: :analytics

    import keys: %w[operations.record_sighting], from: :security

    import keys: %w[repos.task_source_queries], from: :tasks

    export %w[operations.revoke_client repos.oauth_client_queries]
  end
end
