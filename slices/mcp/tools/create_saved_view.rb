# frozen_string_literal: true

module MCP
  module Tools
    class CreateSavedView < Base
      description "Save a view of an admin screen under a name: the screen and the filters it opens with. A " \
                  "filter the screen does not read is dropped"
      input_schema(API::Endpoints::CreateSavedView::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:create_saved_view, input, server_context)
      end
    end
  end
end
