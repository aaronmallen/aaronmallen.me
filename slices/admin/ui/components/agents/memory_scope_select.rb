# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryScopeSelect < Component
          prop :scopes, Blog::Types::Array
          prop :selected, Blog::Types::String.optional
          prop :attributes, Blog::Types::Hash, :**

          def view_template = Select(**@attributes, name: "memory_file[scope]", options:, selected: @selected)

          private

          def options = @scopes.to_h { [it.key, t(Helpers::MemoryScope.label(it.scope), name: it.name.to_s)] }
        end
      end
    end
  end
end
