# frozen_string_literal: true

module Posts
  module Operations
    class ActOnPosts < Blog::Operation
      DRAFT = Blog::Types::PostStatus["draft"]
      FIELDS = %i[act ids tag].freeze
      TAG = Blog::Types::PostBulkAction["tag"]

      include Deps[
        contract: "contracts.bulk_contract",
        delete_post: "operations.delete_post",
        post_repo: "repos.post_repo",
        tag_post: "operations.tag_post",
      ]

      def call(params)
        fields = step validate(params)

        transaction do
          fields[:ids].map { |id| step(single(id, fields).alt_map { [:record, id, it] }) }
        end
      end

      private

      def delete_draft(id)
        post = post_repo.by_id_for_update(id)
        return Failure(:not_found) unless post
        return Failure(:not_draft) unless post.status == DRAFT

        delete_post.call(id)
      end

      def form(params) = FIELDS.to_h { [it, params[it]] }

      def single(id, fields) = fields[:act] == TAG ? tag_post.call(id, fields[:tag]) : delete_draft(id)

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
