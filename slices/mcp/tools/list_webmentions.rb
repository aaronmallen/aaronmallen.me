# frozen_string_literal: true

module MCP
  module Tools
    class ListWebmentions < Base
      description "List the webmentions received, newest first: each with the blog post it " \
                  "names, its type, its status, its source and author, its excerpt, and the reason given for spam. " \
                  "Give post_id to list only the webmentions one post got. counts gives how many webmentions in " \
                  "the range, and for the post when given, sit in each status. Days run on " \
                  "#{Blog::TimeZone::NAME} time, and the answer names it as time_zone; received_at comes in UTC. " \
                  "#{API::Helpers::DayWindow::OPEN_NOTE}. " \
                  "Leave both out to list every webmention. #{API::Helpers::Paging::USAGE}. " \
                  "#{Untrusted::WEBMENTIONS}"
      endpoint
    end
  end
end
