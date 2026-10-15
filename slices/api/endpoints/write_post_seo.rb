# frozen_string_literal: true

module API
  module Endpoints
    class WritePostSeo < Endpoint
      FIELDS = %i[og_image_url og_title].freeze
      SHOWN = %i[id canonical_url og_image_url og_title].freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          og_image_url: { type: "string", description: "a link to the social card image, hosted anywhere" },
          og_title: { type: "string", description: "a title for the social card, when the post title reads badly" },
        },
        required: ["id"],
      }.freeze

      REPLY = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          canonical_url: Helpers::Schema.nullable(Helpers::Schema::STRING),
          og_image_url: Helpers::Schema.nullable(Helpers::Schema::STRING),
          og_title: Helpers::Schema.nullable(Helpers::Schema::STRING),
        },
      ).freeze

      include Deps[save_post_seo: "posts.operations.save_post_seo"]

      def handle(id:, **fields)
        case save_post_seo.call(id, fields.slice(*FIELDS))
          in Success(post) then Success(SHOWN.to_h { [it, post.public_send(it)] })
          in Failure[:invalid, errors] then invalid(Posts.form_complaints(errors))
          in Failure(:not_found) then missing("blog post", id)
          else failed("could not save the social card fields")
        end
      end
    end
  end
end
