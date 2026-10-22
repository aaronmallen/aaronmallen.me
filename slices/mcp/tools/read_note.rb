# frozen_string_literal: true

module MCP
  module Tools
    class ReadNote < Base
      description "Read one note: its title, Markdown body, folder, tags, pin and version, the other notes that " \
                  "link to it and the titles its [[links]] name, each with the ID of the note that holds that " \
                  "title or null when none does yet, and the other records linked to it, grouped by kind. Send the " \
                  "version to edit_note. #{Untrusted::NOTE}. #{Untrusted::LINKS}"
      endpoint
    end
  end
end
