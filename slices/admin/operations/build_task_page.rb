# frozen_string_literal: true

module Admin
  module Operations
    class BuildTaskPage < Operation
      include Blog::Constants

      FORMS = { commenting: EMPTY_HASH, timing: EMPTY_HASH, totaling: EMPTY_HASH }.freeze
      KIND = Blog::Types::RecordKind["task"]

      include Deps[
        current_sprint: "tasks.operations.current_sprint",
        link_targets: "tasks.queries.link_targets",
        list_record_links: "operations.list_record_links",
        task_by_id: "tasks.queries.task_by_id",
        task_timeline: "tasks.queries.task_timeline",
      ]

      def call(id, query: nil, kind: nil, errors: EMPTY_HASH, records: EMPTY_HASH, **forms)
        step roll
        task = step find(id)
        query = Blog::Types::TrimmedText[query]

        { task:, note_html: note_html(task.note), timeline: task_timeline.call(id),
          forms: FORMS.merge(forms),
          linking: { errors:, kind:, query:, targets: link_targets.call(id, query) },
          records: list_record_links.call(KIND, task.id, **records, except: [KIND]) }
      end

      private

      def find(id)
        found(task_by_id.call(id))
      end

      def note_html(note)
        html = ::Tasks::Markdown.to_html(note).strip

        html unless html.empty?
      end

      def roll = current_sprint.call.alt_map { [:unrolled, it] }
    end
  end
end
