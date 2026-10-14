# frozen_string_literal: true

module MCP
  module Tools
    class WritePostSeo < Base
      description "Set the social card fields on one blog post: its Open Graph title and its image URL. " \
                  "A field you leave out keeps what it has, and an empty string clears it. " \
                  "The canonical URL is not yours to set. Nothing else about the post changes"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
