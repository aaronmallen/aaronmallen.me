# frozen_string_literal: true

module Services
  module Repos
    class DefinitionQueries
      DIRECTORY = File.expand_path("../config/definitions", __dir__)
      GROUPS = %w[code social infrastructure].freeze

      def initialize(all = Dir[File.join(DIRECTORY, "*.yml")].map { Definition.load(it) })
        @all = all.sort_by { [GROUPS.index(it.group), it.name] }.freeze
      end

      attr_reader :all
    end
  end
end
