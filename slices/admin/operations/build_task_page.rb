# frozen_string_literal: true

module Admin
  module Operations
    class BuildTaskPage < Blog::Operation
      include Blog::Constants

      include Deps[
        current_sprint: "tasks.operations.current_sprint",
        link_targets: "tasks.queries.link_targets",
        task_by_id: "tasks.queries.task_by_id",
        task_timeline: "tasks.queries.task_timeline",
      ]

      def call(id, query: nil, kind: nil, errors: EMPTY_HASH, commenting: EMPTY_HASH)
        step roll
        task = step find(id)
        query = Blog::Types::TrimmedText[query]

        { task:, note_html: note_html(task.note), timeline: task_timeline.call(id), commenting:,
          linking: { errors:, kind:, query:, targets: link_targets.call(id, query) } }
      end

      private

      def find(id)
        task = task_by_id.call(id)

        task ? Success(task) : Failure(:not_found)
      end

      def note_html(note)
        html = ::Tasks::Markdown.to_html(note).strip

        html unless html.empty?
      end

      def roll = current_sprint.call.alt_map { [:unrolled, it] }
    end
  end
end
