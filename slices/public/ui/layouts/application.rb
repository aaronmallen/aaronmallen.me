# frozen_string_literal: true

module Public
  module UI
    module Layouts
      class Application < Blog::UI::Layouts::Application
        include Components
        include Deps[session_reader: "admin.auth.session_reader"]

        ARTICLE = "article"
        BEACON_DEPTHS = Blog::Types::ScrollDepth.values.select(&:positive?).join(" ")
        BEACON_READ_CAP = Blog::Constants::READ_SECONDS_MAX
        BEACON_REF = Blog::Constants::REF_KEY
        FONTS = %w[
          newsreader/newsreader-latin-opsz-normal.woff2 bricolage-grotesque/bricolage-grotesque-latin-opsz-normal.woff2
        ].freeze
        IMAGE_CARD = "summary_large_image"
        SHARE_IMAGE = "share.png"
        SHARE_IMAGE_SIZE = { width: 1200, height: 630 }.freeze
        STRUCTURED_DATA_TYPE = "application/ld+json"
        WEBSITE = "website"

        def view_template(&)
          document do
            body(class: "pub", data: beacon_data) do
              MainNav(session: admin_session)
              main(id: "main", class: "site-main", &)
              Footer(year: Blog::TimeZone.today.year)
            end
          end
        end

        private

        def admin_session
          session_reader.call(request)
        end

        def article? = page_kind == ARTICLE

        def beacon_data
          {
            beacon: path(:visit), beacon_ref: BEACON_REF, beacon_clicks: article?, beacon_depths: BEACON_DEPTHS,
            beacon_read_cap: BEACON_READ_CAP,
          }
        end

        def own_image
          image = content_for(:image).to_s
          image unless image.empty?
        end

        def page_image = own_image || settings.site_url(asset_url(SHARE_IMAGE))

        def page_image_alt
          own_image ? page_social_title : t(".share_image_alt", owner: settings.owner_name)
        end

        def page_kind = content_for(:kind) || WEBSITE

        def page_path = request.path

        def page_social_title = content_for(:social_title) || content_for(:title) || settings.owner_name

        def page_url = content_for(:canonical) || settings.site_url(page_path)

        def preloaded_fonts = FONTS

        def render_article_tags
          meta(property: "article:author", content: settings.owner_name)
          meta(property: "article:published_time", content: content_for(:published_time))
          meta(property: "article:modified_time", content: content_for(:modified_time))
          content_for(:tags).to_a.each { meta(property: "article:tag", content: it) }
        end

        def render_feed_link
          super
          link(rel: "alternate", type: FEED_TYPE, title: writing_feed_title, href: path(:writing_feed))
        end

        def render_head
          super
          link(rel: "canonical", href: page_url)
          render_structured_data
          script(src: asset_url("public/app.js"), type: "module")
        end

        def render_meta
          super
          robots = content_for(:robots)
          meta(name: "robots", content: robots) if robots
          render_open_graph
          render_twitter_card
        end

        def render_open_graph
          meta(property: "og:type", content: page_kind)
          meta(property: "og:site_name", content: settings.owner_name)
          meta(property: "og:title", content: page_social_title)
          meta(property: "og:url", content: page_url)
          meta(property: "og:description", content: page_description) if page_description
          render_open_graph_image
          render_article_tags if article?
        end

        def render_open_graph_image
          meta(property: "og:image", content: page_image)
          meta(property: "og:image:alt", content: page_image_alt)
          SHARE_IMAGE_SIZE.each { |side, size| meta(property: "og:image:#{side}", content: size) } unless own_image
        end

        def render_structured_data
          data = content_for(:structured_data)
          script(type: STRUCTURED_DATA_TYPE) { raw(safe(JSON.generate(data, script_safe: true))) } if data
        end

        def render_twitter_card
          meta(name: "twitter:card", content: IMAGE_CARD)
          meta(name: "twitter:title", content: page_social_title)
          meta(name: "twitter:description", content: page_description) if page_description
          meta(name: "twitter:image", content: page_image)
          meta(name: "twitter:image:alt", content: page_image_alt)
        end

        def stylesheet = "public/app.css"

        def writing_feed_title = t(".writing_feed", owner: settings.owner_name)
      end
    end
  end
end
