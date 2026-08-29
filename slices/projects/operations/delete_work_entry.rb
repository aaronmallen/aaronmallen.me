# frozen_string_literal: true

module Projects
  module Operations
    class DeleteWorkEntry < Blog::Operation
      include Deps[work_entry_repo: "repos.work_entry_repo"]

      def call(id)
        step deleted(work_entry_repo.delete(id))
      end

      private

      def deleted(entry) = entry ? Success(entry) : Failure(:not_found)
    end
  end
end
