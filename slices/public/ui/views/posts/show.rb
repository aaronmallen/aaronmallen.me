# frozen_string_literal: true

require "time"

module Public
  module UI
    module Views
      module Posts
        class Show < View
          include Components::Posts

          DESCRIPTION_LIMIT = 160

          prop :post, Blog::Types::Instance(ROM::Struct)
          prop :body_html, Blog::Types::String
          prop :headings, Toc::HEADINGS
          prop :edits, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :previous_post, Blog::Types::Instance(ROM::Struct).optional
          prop :next_post, Blog::Types::Instance(ROM::Struct).optional
          prop :syndication_urls, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::String)
          prop :webmentions, Blog::Types::Hash.schema(
            responses: Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)),
            counts: Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer),
          )

          def view_template
            page_meta

            article(class: "post h-entry") do
              head_row
              post_body
              Edits(edits: @edits)
              feedback_note
              Syndication(urls: @syndication_urls)
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
              IconLabel(icon: "fa-solid fa-arrow-left") { t(".back") }
            end
          end

          def description
            @post.written_summary || Blog::Helpers::Truncation.fit(@post.summary, limit: DESCRIPTION_LIMIT)
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
            back_link
            header(class: "post-h") do
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
                IconLabel(icon: ["fa-solid", icon]) { t(label_key) }
              end
              span(class: "post-pager-title") { post.title }
            end
          end

          def post_body
            div(class: "post-g") do
              div do
                div(class: "prose lead e-content") { raw(safe(@body_html)) }
                span(class: "endmark", aria: { hidden: "true" }) { span(class: "glasses") }
              end
              Toc(headings: @headings)
            end
          end

          def social_card
            content_for(:canonical, @post.canonical_url)
            content_for(:description, description)
            content_for(:image, @post.og_image_url)
            content_for(:social_title, @post.og_title)
          end

          def stamp(time) = time.utc.iso8601
        end
      end
    end
  end
end
