# frozen_string_literal: true

module Projects
  module Operations
    class DeleteWorkEntry < Blog::Operation
      include Deps[work_entry_repo: "repos.work_entry_repo"]

      def call(id)
        step found(work_entry_repo.delete(id))
      end
    end
  end
end
