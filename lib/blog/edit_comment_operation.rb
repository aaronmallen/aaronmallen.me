# frozen_string_literal: true

module Blog
  class EditCommentOperation < Operation
    def call(owner_id, id, params)
      step found(comment_queries.editable_comment?(owner_id, id))
      fields = step validate(params)

      transaction do
        comment_photos.call(self.class::PHOTO_OWNER, id, fields[:body])
        comment_mutations.update(id, body: fields[:body])
      end
    end
  end
end
