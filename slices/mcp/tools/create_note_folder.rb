# frozen_string_literal: true

module MCP
  module Tools
    class CreateNoteFolder < Base
      description "Make a note folder from a path such as work/clients, as the admin's New " \
                  "folder box does: each folder on the path that is missing is made, and one that exists is " \
                  "kept. It answers the last folder on the path"
      endpoint
    end
  end
end
