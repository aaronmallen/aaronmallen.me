# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostEditor
      FIELDS = %i[title slug summary tags body publish_at og_title og_image_url canonical_url].freeze
      SEO = %i[og_title og_image_url canonical_url].freeze
      TAG_SEPARATOR = ", "

      include Deps[
        announcement: "posts.operations.compose_announcement",
        build_post_preview: "operations.build_post_preview",
        count_network_lengths: "operations.count_network_lengths",
        list_networks: "operations.list_networks",
        preview_announcement: "operations.preview_announcement",
        received_webmention_count: "social.queries.received_webmention_count",
        suggestion_for_post: "suggestions.queries.for_post",
        webmention_settings: "social.queries.webmention_settings",
      ]

      def call(post: nil, params: nil, errors: Dry::Core::Constants::EMPTY_HASH, view: nil, now: Time.now)
        values = params ? values_from_params(params) : values_from_post(post)
        preview = build_post_preview.call(values:, now:)

        {
          post:,
          values:,
          counts: counts(values, preview),
          errors:,
          now:,
          preview:,
          suggestions: suggestions(post),
          syndication: syndication(values, post, params),
          view:,
          webmentions: webmentions(post, params),
        }
      end

      private

      def counts(values, preview)
        { read_time: preview[:read_time], words: ::Posts::Markdown.word_count(values[:body]) }
      end

      def publish_at(post)
        return Dry::Core::Constants::EMPTY_STRING unless post.published_at

        Blog::TimeZone.input_value(post.published_at)
      end

      def seo_from_post(post) = SEO.to_h { [it, post.public_send(it).to_s] }

      def suggestions(post)
        suggestion = suggestion_for_post.call(post.id) if post

        {
          post_id: post&.id,
          body: post ? post.body : Dry::Core::Constants::EMPTY_STRING,
          edits: suggestion ? suggestion.open_edits : Dry::Core::Constants::EMPTY_ARRAY,
        }
      end

      def syndication(values, post, params)
        body = syndication_body(post, params)
        preview = preview_announcement.call(values)

        {
          body:,
          counts: count_network_lengths.call([body.strip.empty? ? preview : body]).first,
          enabled: syndication_enabled(post, params),
          networks: list_networks.call(selected: syndication_targets(post, params)),
          preview:,
        }
      end

      def syndication_body(post, params)
        return Blog::Types::Text[params[:syndication_body]] if params
        return announcement.call(post) if post

        Dry::Core::Constants::EMPTY_STRING
      end

      def syndication_enabled(post, params)
        return Blog::Types::Checkbox[params[:syndication_enabled]] if params
        return post.syndication_enabled if post

        true
      end

      def syndication_targets(post, params)
        return Array(params[:syndication_targets]).map(&:to_s) if params

        post&.syndication_targets&.to_a
      end

      def values_from_params(params) = FIELDS.to_h { [it, Blog::Types::Text[params[it]]] }

      def values_from_post(post)
        return FIELDS.to_h { [it, Dry::Core::Constants::EMPTY_STRING] } unless post

        {
          title: post.title,
          slug: post.slug,
          summary: post.written_summary.to_s,
          tags: post.tags.map(&:name).join(TAG_SEPARATOR),
          body: post.body,
          publish_at: publish_at(post),
          **seo_from_post(post),
        }
      end

      def webmentions(post, params)
        {
          enabled: webmentions_enabled(post, params),
          received: post ? received_webmention_count.call(post.id) : 0,
        }
      end

      def webmentions_enabled(post, params)
        return Blog::Types::Checkbox[params[:webmentions_enabled]] if params
        return post.webmentions_enabled if post

        webmention_settings.call.enable_on_new_posts
      end
    end
  end
end
