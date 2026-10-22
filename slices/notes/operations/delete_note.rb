# frozen_string_literal: true

module Notes
  module Operations
    class DeleteNote < Blog::Operation
      include Deps[note_mutations: "repos.note_mutations"]

      def call(id) = step found(note_mutations.delete(id))
    end
  end
end
