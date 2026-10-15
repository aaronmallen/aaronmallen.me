# frozen_string_literal: true

module Posts
  module Operations
    class ActOnPosts < Blog::Operation
      TAG = Blog::Types::PostBulkAction["tag"]
      UNTAG = Blog::Types::PostBulkAction["untag"]

      include Deps[
        contract: "contracts.bulk_contract", # rubocop:disable Hanami/UnusedDeps
        delete_post: "operations.delete_post",
        post_mutations: "repos.post_mutations",
        tag_post: "operations.tag_post",
        untag_post: "operations.untag_post",
      ]

      def call(params)
        fields = step validate(params)

        each_record(fields[:ids]) { single(it, fields) }
      end

      private

      def delete_draft(id)
        found(post_mutations.by_id_for_update(id)).bind do |post|
          post.draft? ? delete_post.call(id) : Failure(:not_draft)
        end
      end

      def single(id, fields)
        case fields[:act]
          when TAG then tag_post.call(id, fields[:tag])
          when UNTAG then untag_post.call(id, fields[:tag])
          else delete_draft(id)
        end
      end
    end
  end
end
