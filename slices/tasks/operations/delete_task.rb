# frozen_string_literal: true

module Tasks
  module Operations
    class DeleteTask < Blog::Operation
      COMMENT_OWNER = Blog::Types::PhotoOwner["task_comment"]
      TASK_OWNER = Blog::Types::PhotoOwner["task"]

      include Deps[
        release_photos: "media.operations.release_photos",
        task_comment_queries: "repos.task_comment_queries",
        task_mutations: "repos.task_mutations",
        work_session_mutations: "repos.work_session_mutations",
      ]

      def call(id, at: Time.now)
        transaction do
          comment_ids = task_comment_queries.ids_for_task(id)
          work_session_mutations.close(id, at)
          task = step found(task_mutations.delete(id))
          release_photos.call(TASK_OWNER, id)
          release_photos.call(COMMENT_OWNER, comment_ids)
          task
        end
      end
    end
  end
end
