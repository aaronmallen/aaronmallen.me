# frozen_string_literal: true

module MCP
  module Tools
    class ListWebmentions < Base
      description "List the webmentions received, newest first: each with the blog post it " \
                  "names, its type, its status, its source and author, its excerpt, and the reason given for spam. " \
                  "Give post_id to list only the webmentions one post got. counts gives how many webmentions in " \
                  "the range, and for the post when given, sit in each status. Days run on " \
                  "#{Blog::TimeZone::NAME} time, and the answer names it as time_zone; received_at comes in UTC. " \
                  "Give from, to or both as YYYY-MM-DD to keep only those days; both days sit inside the range. " \
                  "Leave both out to list every webmention. #{Blog::Paging::USAGE}. " \
                  "The source, author name, author URL and excerpt, taken from the sender's page, come marked " \
                  "untrusted. #{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::READ

      class << self
        private

        def answered(found) = found.merge(webmentions: found.fetch(:webmentions).map { Webmentions.marked(it) })
      end
    end
  end
end
