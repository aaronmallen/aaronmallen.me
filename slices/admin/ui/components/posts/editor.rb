# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Editor < Component
          BODY_HEIGHT = "520px"
          PUBLISHED = Blog::Types::PostStatus["published"]
          SEPARATOR = " · "

          prop :post, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :counts, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::Integer)
          prop :errors, Blog::Types::Hash
          prop :now, Blog::Types::Time
          prop :preview, Blog::Types::Hash
          prop :suggestions, Blog::Types::Hash
          prop :syndication, Blog::Types::Hash
          prop :view, Blog::Types::String.optional
          prop :webmentions, Blog::Types::Hash

          def view_template
            back_link
            DeleteForm(post: @post, received: @webmentions[:received]) if @post
            SuggestionForms(post_id: @suggestions[:post_id]) if suggestions?

            Form(action: form_action, data: { post_editor: "", time_zone: Blog::TimeZone::NAME }) do
              page_head
              panes_and_sidebar
            end
          end

          private

          def back_link
            a(class: "btn gh sm editor-back", href: path(:admin_posts)) do
              i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
              span { t(".all_posts") }
            end
          end

          def body_editor
            MarkdownEditor(**body_editor_props) { Preview(**@preview) }
          end

          def body_editor_props
            {
              name: "post[body]", value: @values[:body], height: BODY_HEIGHT, renderer: "posts", id: "post-body",
              label: t(".body"), placeholder: t(".placeholder"), preview_path: path(:admin_preview_post),
              view: @view, view_name: "view",
            }
          end

          def form_action = @post ? path(:admin_update_post, id: @post.id) : path(:admin_create_post)

          def page_head
            header(class: "page-head") do
              title_block
              EditorActions(deletable: !@post.nil?, published: published?, scheduling: scheduling?)
            end
          end

          def panes_and_sidebar
            div(class: "editor") do
              body_editor
              SideStack do
                Suggestions(body: @suggestions[:body], edits: @suggestions[:edits]) if suggestions?
                Publishing(values: @values, errors: @errors, published: published?, scheduling: scheduling?)
                Seo(values: @values, errors: @errors)
                Syndication(errors: @errors, **@syndication)
                Webmentions(**@webmentions)
              end
            end
          end

          def published? = @post&.status == PUBLISHED

          def read_time = @counts[:read_time]

          def read_time_attributes
            { data: { editor_read_time: t(".read_time"), words_per_minute: ::Posts::Markdown::WORDS_PER_MINUTE } }
          end

          def scheduling? = @preview[:time] > @now

          def slug = ::Posts::PostSlug.derive(slug: @values[:slug], title: @values[:title])

          def sub_line
            writing = "#{path(:writing)}/"

            p(class: "page-head-sub") do
              span(data: { editor_path: writing }) { writing + slug }
              plain SEPARATOR
              span(data: { editor_words: "", one: t(".words.one"), other: t(".words.other") }) do
                t(".words", count: word_count)
              end
              plain SEPARATOR
              span(**read_time_attributes) { t(".read_time", count: read_time) }
            end
          end

          def suggestions? = @suggestions[:edits].any?

          def summary_attributes
            {
              **FieldError.control_attributes(:summary, @errors),
              class: "editor-summary",
              type: "text",
              name: "post[summary]",
              value: @values[:summary],
              placeholder: t(".summary_placeholder"),
            }
          end

          def summary_block
            label(class: "editor-summary-label", for: "post-summary") { t(".summary") }
            input(**summary_attributes)
            FieldError(field: :summary, errors: @errors)
          end

          def title_attributes
            {
              **FieldError.control_attributes(:title, @errors),
              class: "editor-title",
              type: "text",
              name: "post[title]",
              value: @values[:title],
              placeholder: t(".title_placeholder"),
              data: { editor_title: "" },
            }
          end

          def title_block
            div(class: "editor-head") do
              label(class: "sr-only", for: "post-title") { t(".title") }
              input(**title_attributes)
              FieldError(field: :title, errors: @errors)
              sub_line
              summary_block
            end
          end

          def word_count = @counts[:words]
        end
      end
    end
  end
end
