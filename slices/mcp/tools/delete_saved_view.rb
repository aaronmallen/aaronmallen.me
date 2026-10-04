# frozen_string_literal: true

module MCP
  module Tools
    class DeleteSavedView < Base
      description "Delete one saved view for good. It cannot come back"
      input_schema(API::Endpoints::DeleteSavedView::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:delete_saved_view, input, server_context)
      end
    end
  end
end
