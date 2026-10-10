# frozen_string_literal: true

module Tasks
  module Operations
    class DeleteTaskComment < Blog::Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["task_comment"]

      include Deps[
        release_photos: "media.operations.release_photos",
        task_comment_mutations: "repos.task_comment_mutations",
      ]

      def call(task_id, id)
        transaction do
          count = step affected(task_comment_mutations.delete_local(task_id, id))
          release_photos.call(PHOTO_OWNER, id)
          count
        end
      end
    end
  end
end
