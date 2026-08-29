# frozen_string_literal: true

require "time"

module Public
  module UI
    module Views
      module Posts
        class Show < View
          include Components::Posts

          NETWORKS = {
            Blog::Types::NetworkName["bluesky"] => %w[fa-bluesky .networks.bluesky].freeze,
            Blog::Types::NetworkName["mastodon"] => %w[fa-mastodon .networks.mastodon].freeze,
          }.freeze

          def initialize(post:, body_html:, previous_post:, next_post:, syndication_urls:, webmentions:)
            super()
            @post = post
            @body_html = body_html
            @previous_post = previous_post
            @next_post = next_post
            @syndication_urls = syndication_urls
            @webmentions = webmentions
          end

          def view_template
            page_meta

            article(class: "post h-entry") do
              back_link
              head_row
              div(class: "post-body e-content") { raw(safe(@body_html)) }
              feedback_note
              syndication_row
              Responses(**@webmentions)
              footer_row
            end
          end

          private

          def article_meta
            content_for(:kind, Layouts::Application::ARTICLE)
            content_for(:modified_time, stamp(@post.updated_at))
            content_for(:published_time, stamp(@post.published_at))
            content_for(:tags, @post.tags.map(&:name))
          end

          def back_link
            a(class: "post-back", href: path(:writing)) do
              i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
              span { t(".back") }
            end
          end

          def feedback_note
            p(class: "eyebrow") do
              plain t(".feedback.before")
              whitespace
              a(href: path(:contact)) { t(".feedback.link") }
              plain t(".feedback.after")
            end
          end

          def footer_row
            footer(class: "post-footer") do
              a(class: "post-footer-link", href: path(:writing)) { t(".all_writing") }
              nav(class: "post-pager", aria: { label: t(".pager_label") }) do
                pager_link(@previous_post, rel: "prev", label_key: ".previous", icon: "fa-arrow-left")
                pager_link(@next_post, rel: "next", label_key: ".next", icon: "fa-arrow-right")
              end
            end
          end

          def head_row
            header do
              h1(class: "post-title p-name") { @post.title }
              data(class: "u-url", value: path(:post, slug: @post.slug))
              Meta(time: @post.published_at, tags: @post.tags, read_time: @post.read_time)
            end
          end

          def page_meta
            content_for(:title, @post.title)
            content_for(:webmention, path(:webmention)) if @post.webmentions_enabled
            social_card
            article_meta
          end

          def pager_link(post, rel:, label_key:, icon:)
            return unless post

            a(class: ["post-pager-link", rel], href: path(:post, slug: post.slug), rel:) do
              span(class: "post-pager-label") do
                i(class: ["fa-solid", icon], aria: { hidden: "true" })
                span { t(label_key) }
              end
              span(class: "post-pager-title") { post.title }
            end
          end

          def social_card
            content_for(:canonical, @post.canonical_url)
            content_for(:description, @post.summary)
            content_for(:image, @post.og_image_url)
            content_for(:social_title, @post.og_title)
          end

          def stamp(time) = time.utc.iso8601

          def syndication_link(network, url)
            icon, label_key = NETWORKS[network]

            a(class: "post-syndication-link u-syndication", href: url) do
              i(class: ["fa-brands", icon], aria: { hidden: "true" })
              span { t(label_key) }
            end
          end

          def syndication_row
            return if @syndication_urls.empty?

            div(class: "post-syndication") do
              span { t(".syndication") }
              @syndication_urls.each { |network, url| syndication_link(network, url) }
            end
          end
        end
      end
    end
  end
end
