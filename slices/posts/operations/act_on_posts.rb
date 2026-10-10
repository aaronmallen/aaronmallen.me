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
        post_mutations: "repos.post_mutations",
        tag_post: "operations.tag_post",
      ]

      def call(params)
        fields = step validate(params)

        each_record(fields[:ids]) { single(it, fields) }
      end

      private

      def delete_draft(id)
        found(post_mutations.by_id_for_update(id)).bind do |post|
          post.status == DRAFT ? delete_post.call(id) : Failure(:not_draft)
        end
      end

      def form(params) = FIELDS.to_h { [it, params[it]] }

      def single(id, fields) = fields[:act] == TAG ? tag_post.call(id, fields[:tag]) : delete_draft(id)

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
