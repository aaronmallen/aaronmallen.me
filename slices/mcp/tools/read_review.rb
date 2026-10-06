# frozen_string_literal: true

module MCP
  module Tools
    class ReadReview < Base
      description "Read a week or a month the way the admin's review screen shows it: the tasks done each day, " \
                  "the tasks carried, the posts and social posts that went out, the journal, the commits by repo, " \
                  "the decisions resolved or dropped, with the option chosen, the time worked each day and the " \
                  "period's note, or null, with the totals the screen counts. Give period as week or month " \
                  "and day as YYYY-MM-DD; the period is the one that holds the day. Both may be left out for " \
                  "this week. The title of each done or carried task that syncs from an issue may come from an " \
                  "issue tracker and comes marked untrusted. #{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
