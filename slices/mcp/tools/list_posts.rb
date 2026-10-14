# frozen_string_literal: true

module MCP
  module Tools
    class ListPosts < Base
      description "List every blog post, in any status, and every social post that has not been sent yet. " \
                  "Each blog post gives its slug and tags, says whether it is a draft and when it goes out or " \
                  "went out, and gives its word count, its views, visitors and read-throughs over the last " \
                  "#{Analytics::Repos::AnalyticsRollupQueries::VIEW_DAYS} days, its unique readers (null for a " \
                  "post that went out too long before the site began counting) and the webmentions it received. " \
                  "Give status to keep only the blog posts in it. " \
                  "counts gives how many blog posts in the range sit in each status, whatever status asks for. " \
                  "Give from, to or both as YYYY-MM-DD, in #{Blog::TimeZone::NAME} time, to keep only the " \
                  "blog posts whose publish time falls inside those days; a post with no publish time then " \
                  "drops out. " \
                  "The range leaves the social posts alone. Both lists page together: page 2 holds the second " \
                  "page of each. #{Blog::Helpers::Paging::USAGE}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
