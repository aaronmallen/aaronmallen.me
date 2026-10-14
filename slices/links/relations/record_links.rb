# frozen_string_literal: true

module Links
  module Relations
    class RecordLinks < Blog::DB::Relation
      PROJECT = Sequel.cast(Blog::Types::RecordKind["project"], :record_kind)
      TASK = Sequel.cast(Blog::Types::RecordKind["task"], :record_kind)

      schema :record_links, infer: true

      def between(left_kind, left_id, right_kind, right_id) = where(left_kind:, left_id:, right_kind:, right_id:)

      def touching(kind, id)
        pairs = new(dataset.unordered.union(task_projects, alias: :record_links))

        pairs.where(Sequel.|({ left_kind: kind, left_id: id }, { right_kind: kind, right_id: id }))
      end

      private

      def task_projects
        dataset.db[:tasks].exclude(project_id: nil).select(
          Sequel.cast(nil, Integer).as(:id), TASK.as(:left_kind), Sequel[:id].as(:left_id), PROJECT.as(:right_kind),
          Sequel[:project_id].as(:right_id), Sequel[:updated_at].as(:created_at),
        )
      end
    end
  end
end
