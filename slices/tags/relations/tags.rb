# frozen_string_literal: true

module Tags
  module Relations
    class Tags < Blog::DB::Relation
      include Blog::DB::Tags

      JOINS = {
        posts: :post_tags,
        projects: :project_tags,
        journal_entries: :journal_entry_tags,
        tasks: :task_tags,
        decisions: :decision_tags,
        task_tag_rules: :task_tag_rule_tags,
      }.freeze
      KINDS = {
        Blog::Types::TagScope["public"] => %i[posts projects],
        Blog::Types::TagScope["private"] => %i[journal_entries tasks decisions task_tag_rules],
      }.freeze

      schema :tags, infer: true

      def counts_by_kind(scope)
        JOINS.slice(*KINDS.fetch(scope)).transform_values do |join|
          dataset.db[join].group_and_count(:tag_id).as_hash(:tag_id, :count)
        end
      end

      def last_tag_of_rules(id)
        emptied = rules.where(id: rule_tags.where(tag_id: id).select(:task_tag_rule_id)).exclude(others(id).exists)

        emptied.order(:pattern).select_map(:pattern)
      end

      def naming(text) = text.empty? ? self : where(Sequel.like(:name, "%#{dataset.escape_like(text)}%"))

      private

      def others(id) = rule_tags.where(task_tag_rule_id: Sequel[:task_tag_rules][:id]).exclude(tag_id: id)

      def rule_tags = dataset.db[:task_tag_rule_tags]

      def rules = dataset.db[:task_tag_rules]
    end
  end
end
