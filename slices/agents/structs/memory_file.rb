# frozen_string_literal: true

module Agents
  module Structs
    class MemoryFile < Blog::DB::Struct
      HEADINGS = {
        "preference" => "Preferences", "convention" => "Conventions", "gotcha" => "Gotchas", "context" => "Context",
      }.freeze

      def agent_written? = facts.any?(&:agent?)

      def facts = memory_facts

      def markdown
        "<!-- #{[scope, target].compact.join(' ')} · #{facts.size} #{facts.one? ? 'fact' : 'facts'} -->\n\n" \
          "# #{path.delete_suffix('.md')}\n#{sections.join}"
      end

      def target = repo || project_id || task_id

      private

      def sections
        HEADINGS.filter_map do |type, heading|
          listed = facts.select { it.type == type }
          "\n## #{heading}\n\n#{listed.map { "- #{it.text.gsub("\n", "\n  ")}" }.join("\n")}\n" if listed.any?
        end
      end
    end
  end
end
