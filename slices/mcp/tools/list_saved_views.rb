# frozen_string_literal: true

module MCP
  module Tools
    class ListSavedViews < Base
      description "List the saved views, each with its ID, name, screen and filters, by screen and then name. " \
                  "screen narrows the list to one admin screen"
      input_schema(API::Endpoints::ListSavedViews::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:list_saved_views, input, server_context)
      end
    end
  end
end
