# frozen_string_literal: true

module Notes
  module Operations
    class PinNote < Blog::Operation
      include Deps[
        note_mutations: "repos.note_mutations",
        note_queries: "repos.note_queries",
      ]

      def call(id, params)
        step found(note_mutations.update(id, pinned: Blog::Types::Checkbox[params[:pinned]]))

        note_queries.by_id(id)
      end
    end
  end
end
