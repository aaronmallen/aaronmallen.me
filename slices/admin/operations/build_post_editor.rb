# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostEditor
      FIELDS = %i[title slug summary tags body publish_at og_title og_image_url canonical_url edit_note].freeze

      include Deps[
        announcement: "posts.operations.compose_announcement",
        build_post_preview: "operations.build_post_preview",
        check_post_links: "posts.operations.check_post_links",
        count_network_lengths: "social.operations.count_network_lengths",
        list_networks: "operations.list_networks",
        person_queries: "social.repos.person_queries",
        post_queries: "posts.repos.post_queries",
        preview_announcement: "operations.preview_announcement",
        resolve_mentions: "social.operations.resolve_mentions",
        suggestion_queries: "suggestions.repos.suggestion_queries",
        tag_queries: "tags.repos.tag_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      PUBLIC = Blog::Types::TagScope["public"]
      PUBLISHED = Blog::Types::PostStatus["published"]

      def call(
        post: nil, params: nil, errors: Blog::Constants::EMPTY_HASH, noting: Blog::Constants::EMPTY_HASH, view: nil,
        now: Time.now, review: false, links: false
      )
        form = params ? form_from_params(params) : form_from_post(post)
        values = form.slice(*FIELDS)
        document = ::Markdown::Document.new(values[:body])
        preview = build_post_preview.call(values:, now:, document:)

        {
          post:,
          values:,
          counts: { read_time: preview[:read_time], words: document.word_count },
          errors:,
          links: { items: links_in(post), open: links },
          notes: { edits: edits(post), noting: },
          now:,
          preview:,
          suggestions: suggestions(post, review),
          syndication: syndication(values, form),
          tags: tag_queries.all_in(PUBLIC),
          view:,
          webmentions: webmentions(post, form),
        }
      end

      private

      def edits(post)
        return Blog::Constants::EMPTY_ARRAY unless post&.status == PUBLISHED

        post_queries.edits_newest_first(post.id)
      end

      def form_from_params(params)
        FIELDS.to_h { [it, Blog::Types::Text[params[it]]] }.merge(
          syndication_body: Blog::Types::Text[params[:syndication_body]],
          syndication_enabled: Blog::Types::Checkbox[params[:syndication_enabled]],
          syndication_targets: Array(params[:syndication_targets]).map(&:to_s),
          webmentions_enabled: Blog::Types::Checkbox[params[:webmentions_enabled]],
        )
      end

      def form_from_post(post)
        unless post
          return FIELDS.to_h { [it, Blog::Constants::EMPTY_STRING] }.merge(
            syndication_body: Blog::Constants::EMPTY_STRING,
            syndication_enabled: true,
            syndication_targets: nil,
            webmentions_enabled: webmention_queries.settings.enable_on_new_posts,
          )
        end

        post.form.slice(*FIELDS).merge(
          edit_note: Blog::Constants::EMPTY_STRING,
          syndication_body: announcement.call(post),
          syndication_enabled: post.syndication_enabled,
          syndication_targets: post.syndication_targets&.to_a,
          webmentions_enabled: post.webmentions_enabled,
        )
      end

      def links_in(post)
        return Blog::Constants::EMPTY_ARRAY unless post

        checks = post.status == PUBLISHED ? post_queries.link_checks(post.id) : Blog::Constants::EMPTY_HASH
        check_post_links.links(post.body_html).map { |url, text| { url:, text:, check: checks[url] } }
      end

      def suggestions(post, review)
        suggestion = suggestion_queries.for_post(post.id) if post && post.status != PUBLISHED

        {
          post_id: post&.id,
          body: post ? post.body : Blog::Constants::EMPTY_STRING,
          edits: suggestion ? suggestion.open_edits : Blog::Constants::EMPTY_ARRAY,
          review:,
        }
      end

      def syndication(values, form)
        body = form[:syndication_body]
        preview = preview_announcement.call(values)

        {
          body:,
          counts: count_network_lengths.call([body.strip.empty? ? preview : body]).first,
          enabled: form[:syndication_enabled],
          handles: resolve_mentions.handles(person_queries.all),
          networks: list_networks.call(selected: form[:syndication_targets]),
          preview:,
        }
      end

      def webmentions(post, form)
        { enabled: form[:webmentions_enabled], received: post ? webmention_queries.received_count(post.id) : 0 }
      end
    end
  end
end
