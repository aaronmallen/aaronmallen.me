# frozen_string_literal: true

module MCP
  module Tools
    class ListWebmentions < Base
      description "List the webmentions received over a range of days, newest first: each with the blog post it " \
                  "names, its type, its status, its source and author, its excerpt, and the reason given for spam. " \
                  "Give post_id to list only the webmentions one post got. Days run on " \
                  "#{Blog::TimeZone::NAME} time, and the answer names it as time_zone; received_at comes in UTC. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range. #{Blog::Paging::USAGE}. " \
                  "The author name and excerpt, taken from the sender's page, come marked untrusted. " \
                  "#{Untrusted::WARNING}"
      input_schema(API::Endpoints::ListWebmentions::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input)
          hand_over(:list_webmentions, input, server_context) do |found|
            found.merge(webmentions: found.fetch(:webmentions).map { Webmentions.marked(it) })
          end
        end
      end
    end
  end
end
