# frozen_string_literal: true

require "time"

module MCP
  module Tools
    class PostWrite < Base
      CARD = %i[og_title og_image_url canonical_url].freeze
      CHECKED = Blog::Constants::CHECKED
      EMPTY = Blog::Constants::EMPTY_STRING
      FLAGS = %i[syndication_enabled webmentions_enabled].freeze
      INVALID = "is not valid"
      TAG_SEPARATOR = ", "
      UNCHECKED = "0"
      UNSAVED = "could not save the blog post"
      URL = "needs a URL starting with http:// or https://"

      COMPLAINTS = {
        "announcement_too_long" => "is empty, and the title and link sent in its place run over a network's limit",
        "blank" => "is empty",
        Blog::Contract::CONTROL => "holds a control character",
        "locked" => "cannot change once the post is published",
        "reserved" => "belongs to a page on the site",
        Blog::Contract::SKIPPED => "names a time the clocks skip in Chicago",
        "taken" => "belongs to another post",
        "too_long" => "runs over a network's limit",
        "unknown_mention" => "mentions someone who is not in the directory",
      }.freeze

      FIELD_COMPLAINTS = {
        canonical_url: { Blog::Contract::FORMAT => URL },
        edit_note: {
          "blank" => "is needed when the body of a published post changes: say what changed and why",
          "long" => "runs over 500 characters",
        },
        og_image_url: { Blog::Contract::FORMAT => URL },
        publish_at: { Blog::Contract::FORMAT => "needs a time as YYYY-MM-DDTHH:MM, in Chicago time" },
        slug: {
          "blank" => "needs a letter or number, from itself or from the title",
          Blog::Contract::FORMAT => "takes lowercase letters, numbers and single dashes",
        },
        tags: { Blog::Contract::FORMAT => "each take lowercase letters, numbers and single dashes" },
      }.freeze

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

        def announcement(post)
          {
            syndication_body: post.syndication_body,
            syndication_enabled: post.syndication_enabled ? CHECKED : UNCHECKED,
            syndication_targets: post.syndication_targets.to_a,
          }
        end

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

        def missing(id) = refuse("no blog post has the ID #{id}")

        def reason(field, token) = FIELD_COMPLAINTS.dig(field, token) || COMPLAINTS.fetch(token, INVALID)

        def saved(result, id = nil)
          case result
          in Success[outcome, post] then answer(written(post).merge(outcome: outcome.to_s))
          in Failure[:invalid, errors] then refuse(complaint(errors))
          in Failure(:not_found) then missing(id)
          else refuse(UNSAVED)
          end
        end

        def stored(post)
          {
            title: post.title,
            slug: post.slug,
            summary: post.written_summary.to_s,
            tags: post.tags.map(&:name).join(TAG_SEPARATOR),
            body: post.body,
            publish_at: post.published_at ? Blog::TimeZone.input_value(post.published_at) : EMPTY,
            **CARD.to_h { [it, post.public_send(it).to_s] },
            **announcement(post),
          }
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
