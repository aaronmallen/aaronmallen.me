# frozen_string_literal: true

module MCP
  module Tools
    class EditNote < Base
      description "Change a note's title, body or tags, as the admin's editor saves it. Send the version " \
                  "read_note gave: the edit is refused when the note changed since, so read it again and redo the " \
                  "edit. A new title rewrites [[links]] to the old one in every other note; relinked counts them. " \
                  "Tags replace the ones it carries. #{Untrusted::NOTES}"
      endpoint
    end
  end
end
