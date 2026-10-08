# frozen_string_literal: true

module MCP
  module Tools
    class ReadWebmentionSettings < Base
      SCHEMA = { additionalProperties: false }.freeze

      description "Read the webmention settings: whether the site receives them, sends them when a post goes " \
                  "live, approves known authors on its own, turns them on for new posts, accepts Bridgy, and which " \
                  "hosts are each one person's site"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["read"]

      class << self
        include WebmentionSettingsAnswer

        def call(server_context:) = answer(settings_entry(dep(:webmention_queries, server_context).settings))
      end
    end
  end
end
