# frozen_string_literal: true

module Admin
  module Helpers
    module MemoryScope
      ICONS = {
        "global" => "fa-solid fa-globe", "repo" => "fa-brands fa-github", "project" => "fa-solid fa-cube",
        "task" => "fa-solid fa-list-check",
      }.freeze
      KINDS = "memories_page.kinds"
      LABELS = "memories_page.scopes"
      LISTED_FOR = "memories_page.listed_for"
      SEPARATOR = ":"
      TARGETS = ::Agents::Contracts::MemoryScopeContract::TARGETS

      module_function

      def fields(key)
        scope, target = key.to_s.split(SEPARATOR, 2)
        field = TARGETS[scope]

        field ? { scope:, field => target } : { scope: }
      end

      def icon(scope) = ICONS.fetch(scope)

      def key(file) = key_for(file.scope, file.target)

      def key_for(scope, target) = [scope, target].compact.join(SEPARATOR)

      def kind(scope) = "#{KINDS}.#{scope}"

      def label(scope) = "#{LABELS}.#{scope}"

      def listed_for(scope, named: false) = "#{LISTED_FOR}.#{named ? :named : :unnamed}.#{scope}"
    end
  end
end
