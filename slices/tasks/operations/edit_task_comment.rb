# frozen_string_literal: true

module Tasks
  module Operations
    class EditTaskComment < Blog::EditCommentOperation
      PHOTO_OWNER = Blog::Types::PhotoOwner["task_comment"]

      include Deps[
        comment_mutations: "repos.task_comment_mutations",
        comment_photos: "media.operations.claim_photos",
        comment_queries: "repos.task_comment_queries",
        contract: "contracts.task_comment_contract",
      ]
    end
  end
end
