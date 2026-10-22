# frozen_string_literal: true

module MCP
  module Tools
    class ListNotes < Base
      description "List every note, by title, with its folder, whether it is pinned and when it last changed, as " \
                  "the admin's notes tree shows them. Bodies stay out; read_note gives one whole. count gives the " \
                  "notes listed. #{Untrusted::NOTES}"
      endpoint
    end
  end
end
