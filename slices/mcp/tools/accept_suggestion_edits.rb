# frozen_string_literal: true

module MCP
  module Tools
    class AcceptSuggestionEdits < Base
      description "Accept pending edits from one set of suggested edits, as the admin does, and write them into " \
                  "the draft or scheduled blog post or unsent social post. An edit whose original text no longer " \
                  "appears once goes stale, and one that would push a social post past a network's limit is " \
                  "refused; both stay out of the text. Edits that would leave a social post part empty change " \
                  "nothing"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
