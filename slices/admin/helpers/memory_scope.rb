# frozen_string_literal: true

module Admin
  module Helpers
    module MemoryScope
      LABELS = "memories_page.scopes"
      SEPARATOR = ":"
      TARGETS = ::Agents::Contracts::MemoryScopeContract::TARGETS

      module_function

      def fields(key)
        scope, target = key.to_s.split(SEPARATOR, 2)
        field = TARGETS[scope]

        field ? { scope:, field => target } : { scope: }
      end

      def key(file) = [file.scope, file.target].compact.join(SEPARATOR)

      def label(scope) = "#{LABELS}.#{scope}"
    end
  end
end
