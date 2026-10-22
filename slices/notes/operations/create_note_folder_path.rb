# frozen_string_literal: true

module Notes
  module Operations
    class CreateNoteFolderPath < Blog::Operation
      include Deps[
        "operations.create_note_folder",
        note_queries: "repos.note_queries",
      ]

      def call(path)
        names = Blog::Types::Text[path].split("/").map(&:strip).reject(&:empty?)

        transaction { names.reduce(nil) { |parent, name| step place(parent&.id, name) } }
      end

      private

      def place(parent_id, name)
        found = note_queries.child_folder(parent_id, name)

        found ? Success(found) : create_note_folder.call(name:, parent_id:)
      end
    end
  end
end
