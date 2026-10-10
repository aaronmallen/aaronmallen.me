# frozen_string_literal: true

module MCP
  module Tools
    class ReadReview < Base
      description "Read a week or a month the way the admin's review screen shows it: the tasks done each day, " \
                  "the tasks carried, the posts and social posts that went out, the journal, the commits by repo, " \
                  "the decisions resolved or dropped, with the option chosen, the time worked each day, the journal " \
                  "entries and posts from the same dates in earlier years, newest first, and the period's note, " \
                  "or null, with the totals the screen counts. Give period as week or month and day as " \
                  "YYYY-MM-DD; the period is the one that holds the day. Both may be left out for this week. " \
                  "Each done task lists its contributors, the owner when it lists none, and contributor, agent " \
                  "and model keep only the done tasks that match; the other sections stay whole. " \
                  "The title of each done or carried task that syncs from an issue may come from an issue " \
                  "tracker and comes marked untrusted. #{Untrusted::WARNING}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
