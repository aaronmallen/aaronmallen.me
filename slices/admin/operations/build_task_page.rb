# frozen_string_literal: true

module Admin
  module Operations
    class BuildTaskPage
      include Dry::Core::Constants

      include Deps[link_targets: "tasks.queries.link_targets", task_by_id: "tasks.queries.task_by_id"]

      def call(id, query: nil, kind: nil, errors: EMPTY_HASH)
        task = task_by_id.call(id)
        return unless task

        query = Blog::Types::TrimmedText[query]

        { task:, note_html: note_html(task.note),
          linking: { errors:, kind:, query:, targets: link_targets.call(id, query) } }
      end

      private

      def note_html(note)
        html = ::Tasks::Markdown.to_html(note).strip

        html unless html.empty?
      end
    end
  end
end
