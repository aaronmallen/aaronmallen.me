# frozen_string_literal: true

module Agents
  module Structs
    class MemoryFile < Blog::DB::Struct
      HEADINGS = {
        "preference" => "Preferences", "convention" => "Conventions", "gotcha" => "Gotchas", "context" => "Context",
      }.freeze

      def description_by_agent? = !description_agent.nil?

      def facts = memory_facts

      def markdown
        "<!-- #{header} -->\n\n# #{path.delete_suffix('.md')}\n#{sections.join}"
      end

      def target = repo || project_id || task_id

      private

      def bullet(fact) = "- [fact #{fact.id}] #{fact.text.gsub("\n", "\n  ")}"

      def header
        ["file #{id}", [scope, target].compact.join(" "), "#{facts.size} #{facts.one? ? 'fact' : 'facts'}"].join(" · ")
      end

      def sections
        HEADINGS.filter_map do |type, heading|
          listed = facts.select { it.type == type }
          "\n## #{heading}\n\n#{listed.map { bullet(it) }.join("\n")}\n" if listed.any?
        end
      end
    end
  end
end
