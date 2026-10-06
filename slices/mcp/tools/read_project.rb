# frozen_string_literal: true

module MCP
  module Tools
    class ReadProject < Base
      description "Read one project by ID, such as a project hit from search: every field list_projects gives, " \
                  "created_at, updated_at and the records linked to it, grouped by kind. #{Untrusted::LINKS}"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
