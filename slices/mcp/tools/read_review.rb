# frozen_string_literal: true

module MCP
  module Tools
    class ReadReview < Base
      description "Read a week or a month the way the admin's review screen shows it: the tasks done each day, " \
                  "the tasks carried, the posts and social posts that went out, the journal, the commits by repo " \
                  "and the time worked each day, with the totals the screen counts. Give period as week or month " \
                  "and day as YYYY-MM-DD; the period is the one that holds the day. Both may be left out for " \
                  "this week"
      input_schema(API::Endpoints::ReadReview::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:read_review, input, server_context)
      end
    end
  end
end
