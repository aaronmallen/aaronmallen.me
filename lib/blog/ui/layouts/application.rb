# frozen_string_literal: true

module Blog
  module UI
    module Layouts
      class Application < Phlex::Hanami::Layout
        include Components
        include Deps["settings"]

        FEED_TYPE = "application/atom+xml"
        FONT_TYPE = "font/woff2"
        ICON_TYPE = "image/svg+xml"
        MANIFEST_PATH = "/site.webmanifest"
        THEME_COOKIE = ThemeScript::COOKIE
        THEMES = {
          "light" => { color: "#faf4f2", icon: "fa-sun", label_key: ".themes.light" }.freeze,
          "dark" => { color: "#222222", icon: "fa-moon", label_key: ".themes.dark" }.freeze,
        }.freeze

        private

        def document
          doctype

          html(lang: "en", data: { theme_cookie: THEME_COOKIE }) do
            head { render_head }
            yield
          end
        end

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

        def preloaded_fonts = []

        def render_feed_link
          link(rel: "alternate", type: FEED_TYPE, title: page_title, href: page_feed) if page_feed
        end

        def render_font_preloads
          preloaded_fonts.each do |font|
            link(rel: "preload", href: asset_url(font), as: "font", type: FONT_TYPE, crossorigin: "anonymous")
          end
        end

        def render_head
          render_meta
          title { page_title }
          render_icon_links
          render_feed_link
          render_webmention_link
          render_font_preloads
          link(rel: "stylesheet", href: asset_url(stylesheet))
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
          script { raw(safe(ThemeScript::SOURCE)) }
          meta(name: "viewport", content: "width=device-width, initial-scale=1")
          meta(name: "color-scheme", content: "light dark")
          render_theme_colors
          meta(name: "description", content: page_description) if page_description
        end

        def render_theme_colors
          THEMES.each do |scheme, theme|
            meta(name: "theme-color", media: "(prefers-color-scheme: #{scheme})", content: theme[:color])
          end
        end

        def render_webmention_link
          link(rel: "webmention", href: page_webmention) if page_webmention
        end

        def title_suffix = settings.owner_name
      end
    end
  end
end
