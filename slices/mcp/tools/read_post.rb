# frozen_string_literal: true

module MCP
  module Tools
    class ReadPost < Base
      description "Read one blog post with all the admin editor shows: its title, slug, status, summary, tags, " \
                  "dates, markdown body, social card fields, announcement and the networks it goes to, whether " \
                  "it sends webmentions and how many it has received, its word count and read time, the edit " \
                  "notes left on it newest first, the suggested edits still open on it and the records linked " \
                  "to it, grouped by kind. #{Untrusted::LINKS}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
