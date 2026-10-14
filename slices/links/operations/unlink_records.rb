# frozen_string_literal: true

module Links
  module Operations
    class UnlinkRecords < Blog::Operation
      include Deps[
        record_link_mutations: "repos.record_link_mutations",
        set_task_project: "tasks.operations.set_task_project",
      ]

      def call(kind, id, other_kind, other_id)
        sides = step sides([kind, id], [other_kind, other_id])

        step(record_link_mutations.task_project?(*sides) ? clear(*sides) : unlink(*sides))
      end

      private

      def clear(*sides)
        task_id, project_id = record_link_mutations.sorted(*sides).map(&:last)

        set_task_project.call(task_id, nil, from: project_id).or { Failure(:not_found) }
      end

      def side(kind, id)
        id = Blog::Types::IdParam[id]

        [kind, id] if id
      end

      def sides(*pairs)
        known = pairs.map { side(*it) }

        found(known.all? && known)
      end

      def unlink(*sides) = affected(record_link_mutations.unlink(*sides))
    end
  end
end
