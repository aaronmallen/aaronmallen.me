# frozen_string_literal: true

module MCP
  module Tools
    class UpdateSavedView < Base
      description "Rename one saved view, change its filters, or both. A field you leave out keeps what it has, " \
                  "and new filters replace the old ones whole. Its screen stays as it is"
      input_schema(API::Endpoints::UpdateSavedView::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:update_saved_view, input, server_context)
      end
    end
  end
end
