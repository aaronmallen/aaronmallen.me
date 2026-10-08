# frozen_string_literal: true

module MCP
  module Tools
    class SaveReviewNote < Base
      description "Write the note on a week or a month the way the admin's review screen saves it, replacing " \
                  "any note the period holds. Give period as week or month, week when left out, day as " \
                  "YYYY-MM-DD inside the period, and body as Markdown. read_review returns the note"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
