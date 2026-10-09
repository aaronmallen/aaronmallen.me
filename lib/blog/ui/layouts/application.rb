# frozen_string_literal: true

module Blog
  module UI
    module Layouts
      class Application < Phlex::Hanami::Layout
        include Components

        FEED_TYPE = "application/atom+xml"
        ICON_TYPE = "image/svg+xml"
        MANIFEST_PATH = "/site.webmanifest"
        THEME_COLORS = { "light" => "#ffffff", "dark" => "#272822" }.freeze
        THEME_COOKIE = "site_theme"
        THEMES = %w[light dark].freeze

        private

        def page_description
          description = content_for(:description).to_s.strip
          description unless description.empty?
        end

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
          render_icon_links
          render_feed_link
          render_webmention_link
          link(rel: "stylesheet", href: asset_url("app.css"))
          script(src: asset_url("app.js"), type: "module")
        end

        def render_icon_links
          link(rel: "icon", href: asset_url("favicon.ico"), sizes: "32x32")
          link(rel: "icon", href: asset_url("favicon.svg"), type: ICON_TYPE)
          link(rel: "apple-touch-icon", href: asset_url("apple-touch-icon.png"))
          link(rel: "manifest", href: MANIFEST_PATH)
        end

        def render_meta
          meta(charset: "utf-8")
          meta(name: "viewport", content: "width=device-width, initial-scale=1")
          meta(name: "color-scheme", content: saved_theme || "light dark")
          render_theme_colors
          meta(name: "description", content: page_description) if page_description
        end

        def render_theme_colors
          THEME_COLORS.each do |scheme, color|
            meta(name: "theme-color", media: "(prefers-color-scheme: #{scheme})", content: color)
          end
        end

        def render_webmention_link
          link(rel: "webmention", href: page_webmention) if page_webmention
        end

        def saved_theme
          theme = request.cookies[THEME_COOKIE]
          theme if THEMES.include?(theme)
        end

        def title_suffix = Hanami.app.settings.owner_name
      end
    end
  end
end
