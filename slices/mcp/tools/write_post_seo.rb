# frozen_string_literal: true

module MCP
  module Tools
    class WritePostSeo < Base
      COMPLAINTS = { Blog::Contract::CONTROL => Complaints::CONTROL }.freeze
      FIELDS = %i[og_image_url og_title].freeze
      UNLINKED = "needs a URL starting with http:// or https://"
      UNSAVED = "could not save the social card fields"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: API::Schema::ID,
          og_image_url: { type: "string", description: "a link to the social card image, hosted anywhere" },
          og_title: { type: "string", description: "a title for the social card, when the post title reads badly" },
        },
        required: ["id"],
      }.freeze

      description "Set the social card fields on one blog post: its Open Graph title and its image URL. " \
                  "A field you leave out keeps what it has, and an empty string clears it. " \
                  "The canonical URL is not yours to set. Nothing else about the post changes"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:, **fields)
          case dep(:save_post_seo, server_context).call(id, fields.slice(*FIELDS))
          in Success(post) then answer(seo(post))
          in Failure[:invalid, errors] then refuse(complaint(errors))
          in Failure(:not_found) then refuse("no blog post has the ID #{id}")
          else refuse(UNSAVED)
          end
        end

        private

        def complaint(errors)
          errors.map { |field, (token)| "#{field} #{COMPLAINTS.fetch(token, UNLINKED)}" }.join("; ")
        end

        def seo(post)
          {
            id: post.id,
            canonical_url: post.canonical_url,
            og_image_url: post.og_image_url,
            og_title: post.og_title,
          }
        end
      end
    end
  end
end
