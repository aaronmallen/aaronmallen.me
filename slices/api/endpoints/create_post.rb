# frozen_string_literal: true

module API
  module Endpoints
    class CreatePost < PostWriteEndpoint
      DRAFT = Blog::Types::PostIntent["draft"]
      SCHEMA = { additionalProperties: false, properties: FIELDS, required: ["title"] }.freeze

      include Deps[save_post: "posts.operations.save_post"]

      def handle(**given) = saved(save_post.call(form(given), intent: DRAFT))
    end
  end
end
