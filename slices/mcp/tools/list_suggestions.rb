# frozen_string_literal: true

module MCP
  module Tools
    class ListSuggestions < Base
      description "List the sets of suggested edits made over a range, newest first, each with the blog post or " \
                  "social post it targets and every edit in it: the original text, its replacement, the reason " \
                  "and its status. A pending edit waits on the author, a stale one no longer matches the text, " \
                  "and accepted and rejected ones are settled. Accept or reject open edits with " \
                  "accept_suggestion_edits and reject_suggestion_edits. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range. #{Blog::Helpers::Paging::USAGE}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
