# frozen_string_literal: true

module MCP
  module Tools
    class ListPeople < Base
      description "List everyone in the mention directory by name, each with its ID, key, name, Mastodon and " \
                  "Bluesky handles, created_at and updated_at. A post or social post mentions a person as @{key}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
