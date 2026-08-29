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
      }.freeze

      schema :tags, infer: true

      def counts_by_kind
        JOINS.transform_values { dataset.db[it].group_and_count(:tag_id).as_hash(:tag_id, :count) }
      end
    end
  end
end
