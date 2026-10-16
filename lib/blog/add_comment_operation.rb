# frozen_string_literal: true

module Blog
  class AddCommentOperation < Operation
    def call(owner_id, params)
      step found(comment_owners.exist?(owner_id))
      fields = step validate(params)

      transaction do
        comment = comment_mutations.create(self.class::OWNER_KEY => owner_id, body: fields[:body])
        comment_photos.call(self.class::PHOTO_OWNER, comment.id, comment.body)
        comment
      end
    end
  end
end
