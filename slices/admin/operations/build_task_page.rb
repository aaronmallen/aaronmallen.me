# frozen_string_literal: true

module Admin
  module Operations
    class BuildTaskPage < Blog::Operation
      include Blog::Constants

      FORMS = { commenting: EMPTY_HASH, timing: EMPTY_HASH, totaling: EMPTY_HASH }.freeze
      KIND = Blog::Types::RecordKind["task"]

      include Deps[
        current_sprint: "tasks.operations.current_sprint",
        list_record_links: "operations.list_record_links",
        task_queries: "tasks.repos.task_queries",
      ]

      def call(id, query: nil, kind: nil, errors: EMPTY_HASH, records: EMPTY_HASH, **forms)
        step roll
        task = step find(id)
        query = Blog::Types::TrimmedText[query]

        { task:, note_html: note_html(task.note), timeline: task_queries.timeline(id),
          forms: FORMS.merge(forms),
          linking: { errors:, kind:, query:, targets: task_queries.link_targets(id, query) },
          records: list_record_links.call(KIND, task.id, **records, except: [KIND]) }
      end

      private

      def find(id)
        found(task_queries.detailed(id))
      end

      def note_html(note)
        html = ::Tasks::Markdown.to_html(note).strip

        html unless html.empty?
      end

      def roll = current_sprint.call.alt_map { [:unrolled, it] }
    end
  end
end
