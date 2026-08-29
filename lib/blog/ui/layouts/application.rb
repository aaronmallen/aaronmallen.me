# frozen_string_literal: true

module Blog
  module UI
    module Layouts
      class Application < Phlex::Hanami::Layout
        include Components

        FEED_TYPE = "application/atom+xml"
        THEME_COOKIE = "site_theme"
        THEMES = %w[light dark].freeze

        private

        def page_description = content_for(:description)

        def page_feed = content_for(:feed)

        def page_title
          title = content_for(:title)
          title ? "#{title} | #{title_suffix}" : title_suffix
        end

        def page_webmention = content_for(:webmention)

        def render_feed_link
          link(rel: "alternate", type: FEED_TYPE, title: page_title, href: page_feed) if page_feed
        end

        def render_head
          render_meta
          title { page_title }
          link(rel: "icon", href: asset_url("favicon.svg"))
          render_feed_link
          render_webmention_link
          link(rel: "stylesheet", href: asset_url("app.css"))
          script(src: asset_url("app.js"), type: "module")
        end

        def render_meta
          meta(charset: "utf-8")
          meta(name: "viewport", content: "width=device-width, initial-scale=1")
          meta(name: "color-scheme", content: saved_theme || "light dark")
          meta(name: "description", content: page_description) if page_description
        end

        def render_webmention_link
          link(rel: "webmention", href: page_webmention) if page_webmention
        end

        def saved_theme
          theme = request.cookies[THEME_COOKIE]
          theme if THEMES.include?(theme)
        end

        def title_suffix = Blog::Owner.full_name
      end
    end
  end
end
