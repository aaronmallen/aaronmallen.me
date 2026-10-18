# frozen_string_literal: true

module Links
  module Relations
    class RecordLinks < Blog::DB::Relation
      MEMORY_FILE = Sequel.cast(Blog::Types::RecordKind["memory_file"], :record_kind)
      PROJECT = Sequel.cast(Blog::Types::RecordKind["project"], :record_kind)
      RELATED = Sequel.cast(Blog::Types::RecordLinkRelation["related"], :record_link_relation)
      SCOPED_ID = Sequel.function(:coalesce, :task_id, :project_id)
      SCOPED_KIND = Sequel.cast(Sequel.cast(:scope, :text), :record_kind)
      SCOPES = %w[task project].freeze
      TASK = Sequel.cast(Blog::Types::RecordKind["task"], :record_kind)

      schema :record_links, infer: true

      def between(left_kind, left_id, right_kind, right_id) = where(left_kind:, left_id:, right_kind:, right_id:)

      def implied = new(task_projects.union(scoped_memory_files, alias: :record_links))

      def touching(kind, id)
        pairs = new(dataset.unordered.union(implied.dataset, alias: :record_links))

        pairs.where(Sequel.|({ left_kind: kind, left_id: id }, { right_kind: kind, right_id: id }))
      end

      private

      def scoped_memory_files
        dataset.db[:memory_files].where(scope: SCOPES).select(
          Sequel.cast(nil, Integer).as(:id), SCOPED_KIND.as(:left_kind), SCOPED_ID.as(:left_id),
          MEMORY_FILE.as(:right_kind), Sequel[:id].as(:right_id), Sequel[:created_at].as(:created_at),
          RELATED.as(:relation),
        )
      end

      def task_projects
        dataset.db[:tasks].exclude(project_id: nil).select(
          Sequel.cast(nil, Integer).as(:id), TASK.as(:left_kind), Sequel[:id].as(:left_id), PROJECT.as(:right_kind),
          Sequel[:project_id].as(:right_id), Sequel[:updated_at].as(:created_at), RELATED.as(:relation),
        )
      end
    end
  end
end
