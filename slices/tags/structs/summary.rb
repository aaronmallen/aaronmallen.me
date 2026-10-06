# frozen_string_literal: true

module Tags
  module Structs
    Summary = Data.define(:name, :tags, :posts, :projects, :tasks, :journal_entries, :decisions) do
      def empty? = [posts, projects, tasks, journal_entries, decisions].all?(&:empty?)

      def tag(scope) = tags.find { it.scope == scope }
    end
  end
end
