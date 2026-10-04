# frozen_string_literal: true

module MCP
  module Tools
    class SaveTask < Base
      description "Edit one task, as the admin's task editor does. A field you leave out keeps what it has; " \
                  "tags replace the whole set. The note and each comment's body may come from an issue tracker " \
                  "and come marked untrusted. #{Untrusted::WARNING}"
      input_schema(API::Endpoints::SaveTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:save_task, input, server_context) { Untrusted.task(it) }
      end
    end
  end
end
