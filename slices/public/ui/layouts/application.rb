# frozen_string_literal: true

module Public
  module UI
    module Layouts
      class Application < Blog::UI::Layouts::Application
        include Components

        ARTICLE = "article"
        IMAGE_CARD = "summary_large_image"
        PLAIN_CARD = "summary"
        WEBSITE = "website"

        def view_template(&)
          doctype

          html(lang: "en", data: { site_theme: saved_theme }) do
            head { render_head }
            body(data: { beacon: path(:visit), beacon_ref: ::Analytics::Ref::KEY, beacon_clicks: article? }) do
              MainNav(session: admin_session)
              main(id: "main", class: "site-main", &)
              Footer(year: Blog::TimeZone.today.year)
            end
          end
        end

        private

        def admin_session
          slice["admin.auth.session_reader"].call(request)
        end

        def article? = page_kind == ARTICLE

        def page_card = page_image ? IMAGE_CARD : PLAIN_CARD

        def page_image = content_for(:image)

        def page_kind = content_for(:kind) || WEBSITE

        def page_path = request.path

        def page_social_title = content_for(:social_title) || content_for(:title) || Hanami.app.settings.owner_name

        def page_url = content_for(:canonical) || Hanami.app.settings.site_url(page_path)

        def render_article_tags
          meta(property: "article:author", content: Hanami.app.settings.owner_name)
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
          script(src: asset_url("public/app.js"), type: "module")
        end

        def render_meta
          super
          render_open_graph
          render_twitter_card
        end

        def render_open_graph
          meta(property: "og:type", content: page_kind)
          meta(property: "og:site_name", content: Hanami.app.settings.owner_name)
          meta(property: "og:title", content: page_social_title)
          meta(property: "og:url", content: page_url)
          meta(property: "og:description", content: page_description) if page_description
          meta(property: "og:image", content: page_image) if page_image
          render_article_tags if article?
        end

        def render_twitter_card
          meta(name: "twitter:card", content: page_card)
          meta(name: "twitter:title", content: page_social_title)
          meta(name: "twitter:description", content: page_description) if page_description
          meta(name: "twitter:image", content: page_image) if page_image
        end

        def writing_feed_title = t(".writing_feed", owner: Hanami.app.settings.owner_name)
      end
    end
  end
end
