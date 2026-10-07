# frozen_string_literal: true

require "time"

module MCP
  module Tools
    class PostWrite < Base
      CHECKED = Blog::Constants::CHECKED
      FLAGS = %i[syndication_enabled webmentions_enabled].freeze
      TAG_SEPARATOR = ", "
      UNCHECKED = "0"
      UNSAVED = "could not save the blog post"

      FIELDS = {
        title: { type: "string" },
        slug: { type: "string", description: "lowercase letters, numbers and single dashes; empty takes the title" },
        summary: { type: "string", description: "one line; empty uses the first paragraph of the body" },
        tags: { type: "array", items: { type: "string" }, description: "tag names, such as ruby" },
        body: { type: "string", description: "the whole post, in markdown" },
        publish_at: {
          type: "string",
          description: "when the post goes out, as YYYY-MM-DDTHH:MM in Chicago time; empty leaves it unset",
        },
        og_title: { type: "string", description: "a title for the social card; empty uses the post title" },
        og_image_url: { type: "string", description: "a link to the social card image" },
        canonical_url: { type: "string", description: "only when the post went out somewhere else first" },
        syndication_body: {
          type: "string",
          description: "the announcement sent when the post goes out; empty sends the title and link",
        },
        syndication_enabled: { type: "boolean", description: "whether to announce the post when it goes out" },
        syndication_targets: {
          type: "array",
          items: { type: "string", enum: Blog::Types::NetworkName.values },
          description: "the networks that get the announcement",
        },
        webmentions_enabled: { type: "boolean", description: "whether the post sends and takes webmentions" },
      }.freeze

      class << self
        private

        def complaint(errors)
          errors.map { |field, (token)| "#{field} #{reason(field, token)}" }.join("; ")
        end

        def form(given)
          given.to_h do |field, value|
            next [field, value.join(TAG_SEPARATOR)] if field == :tags
            next [field, value ? CHECKED : UNCHECKED] if FLAGS.include?(field)

            [field, value]
          end
        end

        def missing(id) = refuse(API::Wording.missing("blog post", id))

        def reason(field, token) = API::Endpoints::Posts.field_reason(field, token)

        def saved(result, id = nil)
          case result
            in Success[outcome, post] then answer(written(post).merge(outcome: outcome.to_s))
            in Failure[:invalid, errors] then refuse(complaint(errors))
            in Failure(:not_found) then missing(id)
            else refuse(UNSAVED)
          end
        end

        def written(post)
          {
            id: post.id,
            status: post.status,
            title: post.title,
            slug: post.slug,
            published_at: post.published_at&.utc&.iso8601,
          }
        end
      end
    end
  end
end
