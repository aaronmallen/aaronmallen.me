# frozen_string_literal: true

module MCP
  module Tools
    class DeletePost < Base
      description "Delete one blog post, in any status, for good"
      input_schema(API::Schema.by_id)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          case dep(:delete_post, server_context).call(id)
          in Success(post) then answer(id: post.id, deleted: true)
          in Failure(:not_found) then refuse(API::Wording.missing("blog post", id))
          else refuse("could not delete the blog post")
          end
        end
      end
    end
  end
end
