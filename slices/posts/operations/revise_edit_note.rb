# frozen_string_literal: true

module Posts
  module Operations
    class ReviseEditNote < Blog::Operation
      include Deps[
        claim_post_photos: "operations.claim_post_photos",
        contract: "contracts.edit_note_contract",
        post_edit_repo: "repos.post_edit_repo",
        post_repo: "repos.post_repo",
      ]

      def call(post_id, id, params)
        transaction do
          post = step find(post_id, id)
          fields = step validated(contract.call(note: params[:note]))

          post_edit_repo.update(id, note: fields[:note]).tap { claim_post_photos.call(post) }
        end
      end

      private

      def find(post_id, id)
        post = post_repo.by_id_for_update(post_id)

        post && post_edit_repo.on_post?(post_id, id) ? Success(post) : Failure(:not_found)
      end
    end
  end
end
