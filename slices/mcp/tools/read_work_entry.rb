# frozen_string_literal: true

module MCP
  module Tools
    class ReadWorkEntry < Base
      description "Read one work entry, a role on /projects, by ID, such as a work hit from search: every field " \
                  "list_work_entries gives and the records linked to it, grouped by kind. #{Untrusted::LINKS}"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
