# frozen_string_literal: true

module Admin
  module Helpers
    module MemoryScope
      LABELS = "memories_page.scopes"
      LOADS_FOR = "memories_page.loads_for"
      SEPARATOR = ":"
      TARGETS = ::Agents::Contracts::MemoryScopeContract::TARGETS

      module_function

      def fields(key)
        scope, target = key.to_s.split(SEPARATOR, 2)
        field = TARGETS[scope]

        field ? { scope:, field => target } : { scope: }
      end

      def key(file) = key_for(file.scope, file.target)

      def key_for(scope, target) = [scope, target].compact.join(SEPARATOR)

      def label(scope) = "#{LABELS}.#{scope}"

      def loads_for(scope, named: false) = "#{LOADS_FOR}.#{named ? :named : :unnamed}.#{scope}"
    end
  end
end
