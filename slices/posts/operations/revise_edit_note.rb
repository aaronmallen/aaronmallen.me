# frozen_string_literal: true

module Posts
  module Operations
    class ReviseEditNote < Blog::Operation
      include Deps[contract: "contracts.edit_note_contract", post_edit_repo: "repos.post_edit_repo"]

      def call(post_id, id, params)
        step find(post_id, id)
        fields = step validated(contract.call(note: params[:note]))

        Success(post_edit_repo.update(id, note: fields[:note]))
      end

      private

      def find(post_id, id) = post_edit_repo.on_post?(post_id, id) ? Success(id) : Failure(:not_found)
    end
  end
end
