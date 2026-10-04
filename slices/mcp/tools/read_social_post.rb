# frozen_string_literal: true

module MCP
  module Tools
    class ReadSocialPost < Base
      description "Read one social post by ID, sent or not, such as a social hit from search: its status, " \
                  "targets, times, parts in order, each network's delivery with its link, error and engagement " \
                  "counts, the suggested edits still open and the records linked to it, grouped by kind"
      input_schema(API::Endpoints::ReadSocialPost::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:read_social_post, input, server_context)
      end
    end
  end
end
