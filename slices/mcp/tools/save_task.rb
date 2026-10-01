# frozen_string_literal: true

module MCP
  module Tools
    class SaveTask < Base
      description "Edit one task, as the admin's task editor does. A field you leave out keeps what it has; " \
                  "tags replace the whole set"
      input_schema(API::Endpoints::SaveTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:save_task, input, server_context)
      end
    end
  end
end
