# frozen_string_literal: true

module MCP
  module Tools
    class ReadWorkEntry < Base
      description "Read one work entry, a role on /projects, by ID, such as a work hit from search: every field " \
                  "list_work_entries gives and the records linked to it, grouped by kind"
      input_schema(API::Endpoints::ReadWorkEntry::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:read_work_entry, input, server_context)
      end
    end
  end
end
