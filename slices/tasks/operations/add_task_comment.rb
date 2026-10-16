# frozen_string_literal: true

module Tasks
  module Operations
    class AddTaskComment < Blog::AddCommentOperation
      PHOTO_OWNER = Blog::Types::PhotoOwner["task_comment"]
      OWNER_KEY = :task_id

      include Deps[
        comment_mutations: "repos.task_comment_mutations",
        comment_owners: "repos.task_queries",
        comment_photos: "media.operations.claim_photos",
        contract: "contracts.task_comment_contract",
      ]
    end
  end
end
