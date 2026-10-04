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
      }.freeze
      KINDS = {
        Blog::Types::TagScope["public"] => %i[posts projects],
        Blog::Types::TagScope["private"] => %i[journal_entries tasks decisions],
      }.freeze

      schema :tags, infer: true

      def count_uses(id, scope) = JOINS.values_at(*KINDS.fetch(scope)).sum { dataset.db[it].where(tag_id: id).count }

      def counts_by_kind(scope)
        JOINS.slice(*KINDS.fetch(scope)).transform_values do |join|
          dataset.db[join].group_and_count(:tag_id).as_hash(:tag_id, :count)
        end
      end

      def naming(text) = text.empty? ? self : where(Sequel.like(:name, "%#{dataset.escape_like(text)}%"))
    end
  end
end
