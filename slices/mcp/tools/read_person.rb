# frozen_string_literal: true

module MCP
  module Tools
    class ReadPerson < Base
      description "Read one person in the mention directory by ID, such as a person hit from search: its key, " \
                  "name, Mastodon and Bluesky handles, created_at and updated_at"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
