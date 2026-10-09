# frozen_string_literal: true

module Tags
  module Relations
    class Tags < Blog::DB::Relation
      use :tags

      JOINS = {
        posts: :post_tags,
        projects: :project_tags,
        journal_entries: :journal_entry_tags,
        tasks: :task_tags,
        decisions: :decision_tags,
        task_rules: :task_rule_tags,
        messages: :message_tags,
      }.freeze
      KINDS = {
        Blog::Types::TagScope["public"] => %i[posts projects],
        Blog::Types::TagScope["private"] => %i[journal_entries tasks decisions task_rules messages],
      }.freeze

      schema :tags, infer: true

      def counts_by_kind(scope)
        JOINS.slice(*KINDS.fetch(scope)).transform_values do |join|
          dataset.db[join].group_and_count(:tag_id).as_hash(:tag_id, :count)
        end
      end

      def last_tag_of_rules(id)
        held = rules.where(id: rule_tags.where(tag_id: id).select(:task_rule_id))
        emptied = held.exclude(others(id).exists).exclude(rule_projects.where(task_rule_id: rule_id).exists)

        emptied.order(:pattern).select_map(:pattern)
      end

      def naming(text)
        return self if text.empty?
        return none if unmatchable?(text)

        where(Sequel.like(:name, "%#{dataset.escape_like(text)}%"))
      end

      private

      def others(id) = rule_tags.where(task_rule_id: rule_id).exclude(tag_id: id)

      def rule_id = Sequel[:task_rules][:id]

      def rule_projects = dataset.db[:task_rule_projects]

      def rule_tags = dataset.db[:task_rule_tags]

      def rules = dataset.db[:task_rules]
    end
  end
end
