# frozen_string_literal: true

module Posts
  module Operations
    class PublishDraft < Blog::Operation
      CARD = %i[og_title og_image_url canonical_url].freeze
      CHECKED = Blog::Constants::CHECKED
      DRAFT = Blog::Types::PostStatus["draft"]
      PUBLISH = Blog::Types::PostIntent["publish"]
      TAG_SEPARATOR = ", "
      UNCHECKED = "0"

      include Deps[post_repo: "repos.post_repo", save_post: "operations.save_post"]

      def call(id, now: Time.now)
        transaction do
          step draft(post_repo.by_id_for_update(id))
          step save_post.call(form(post_repo.by_id(id)), id:, intent: PUBLISH, now:)
        end
      end

      private

      def draft(post)
        return Failure(:not_found) unless post

        post.status == DRAFT ? Success(post) : Failure(:not_draft)
      end

      def form(post)
        {
          title: post.title,
          slug: post.slug,
          summary: post.written_summary.to_s,
          tags: post.tags.map(&:name).join(TAG_SEPARATOR),
          body: post.body,
          publish_at: publish_at(post),
          **CARD.to_h { [it, post.public_send(it).to_s] },
          syndication_body: post.syndication_body,
          syndication_enabled: post.syndication_enabled ? CHECKED : UNCHECKED,
          syndication_targets: post.syndication_targets.to_a,
        }
      end

      def publish_at(post)
        post.published_at ? Blog::TimeZone.input_value(post.published_at) : Blog::Constants::EMPTY_STRING
      end
    end
  end
end
