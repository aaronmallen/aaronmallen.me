# frozen_string_literal: true

module MCP
  module Tools
    class ListSavedViews < Base
      description "List the saved views, each with its ID, name, screen and filters, by screen and then name. " \
                  "screen narrows the list to one admin screen"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
