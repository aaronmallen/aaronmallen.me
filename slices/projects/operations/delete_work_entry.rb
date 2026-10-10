# frozen_string_literal: true

module Projects
  module Operations
    class DeleteWorkEntry < Blog::Operation
      include Deps[work_entry_mutations: "repos.work_entry_mutations"]

      def call(id)
        step found(work_entry_mutations.delete(id))
      end
    end
  end
end
