# frozen_string_literal: true

module Posts
  module PostForm
    CARD = %i[og_title og_image_url canonical_url].freeze
    CHECKED = Blog::Constants::CHECKED
    TAG_SEPARATOR = ", "
    UNCHECKED = "0"

    module_function

    def call(post)
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
