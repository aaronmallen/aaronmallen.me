# frozen_string_literal: true

module Posts
  module Operations
    class ReviseEditNote < Blog::Operation
      include Deps[
        claim_post_photos: "operations.claim_post_photos",
        contract: "contracts.edit_note_contract",
        post_edit_mutations: "repos.post_edit_mutations",
        post_mutations: "repos.post_mutations",
        post_queries: "repos.post_queries",
      ]

      def call(post_id, id, params)
        transaction do
          post = step find(post_id, id)
          fields = step validated(contract.call(note: params[:note]))

          post_edit_mutations.update(id, note: fields[:note]).tap { claim_post_photos.call(post) }
        end
      end

      private

      def find(post_id, id)
        post = post_mutations.by_id_for_update(post_id)

        found(post && post_queries.edit_on_post?(post_id, id) && post)
      end
    end
  end
end
