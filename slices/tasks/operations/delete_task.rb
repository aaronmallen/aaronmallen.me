# frozen_string_literal: true

module Tasks
  module Operations
    class DeleteTask < Blog::Operation
      COMMENT_OWNER = Blog::Types::PhotoOwner["task_comment"]
      TASK_OWNER = Blog::Types::PhotoOwner["task"]

      include Deps[
        release_photos: "media.operations.release_photos",
        task_comment_repo: "repos.task_comment_repo",
        task_repo: "repos.task_repo",
        work_session_repo: "repos.work_session_repo",
      ]

      def call(id, at: Time.now)
        transaction do
          comment_ids = task_comment_repo.ids_for_task(id)
          work_session_repo.close(id, at)
          task = step deleted(task_repo.delete(id))
          release_photos.call(TASK_OWNER, id)
          release_photos.call(COMMENT_OWNER, comment_ids)
          task
        end
      end

      private

      def deleted(task) = task ? Success(task) : Failure(:not_found)
    end
  end
end
