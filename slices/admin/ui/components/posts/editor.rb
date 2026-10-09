# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Editor < Component
          BODY_HEIGHT = "520px"
          FORM_DATA = { post_editor: "", time_zone: Blog::TimeZone::NAME }.freeze
          PUBLISHED = Blog::Types::PostStatus["published"]

          prop :post, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :counts, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::Integer)
          prop :errors, Blog::Types::Hash
          prop :notes, Blog::Types::Hash
          prop :now, Blog::Types::Time
          prop :preview, Blog::Types::Hash
          prop :suggestions, Blog::Types::Hash
          prop :syndication, Blog::Types::Hash
          prop :view, Blog::Types::String.optional
          prop :webmentions, Blog::Types::Hash

          def view_template
            back_link
            outside_forms

            Form(action: form_action, class: "post-editor", novalidate: true, data: FORM_DATA) do
              page_head
              SuggestionsBanner(count: @suggestions[:edits].size) if suggestions?
              main
              Details(**details_props)
            end
          end

          private

          def back_link
            BackLink(href: path(:admin_posts), variant: :gh, small: true, class: "editor-back") { t(".all_posts") }
          end

          def body_editor_props
            {
              name: "post[body]", value: @values[:body], height: BODY_HEIGHT, renderer: "posts", id: "post-body",
              label: t(".body"), placeholder: t(".placeholder"), preview_path: path(:admin_preview_post),
              view: @view, view_name: "view", data: { post_body: "", edit_note_watch: "" },
            }
          end

          def details_props
            {
              post: @post, values: @values, errors: @errors, notes: @notes, published: published?,
              scheduling: scheduling?, syndication: @syndication, webmentions: @webmentions,
            }
          end

          def form_action = @post ? path(:admin_update_post, id: @post.id) : path(:admin_create_post)

          def main
            div(class: "editor-main") do
              MarkdownEditor(**body_editor_props) { Preview(**@preview) }
              EditNote(value: @values[:edit_note], errors: @errors) if published?
            end
          end

          def outside_forms
            if @post
              DeleteForm(post: @post, received: @webmentions[:received])
              EditNoteForms(post_id: @post.id, edits: @notes[:edits])
            end
            return unless suggestions?

            SuggestionForms(post_id: @suggestions[:post_id])
            Suggestions(body: @suggestions[:body], edits: @suggestions[:edits], review: @suggestions[:review])
          end

          def page_head
            EditorHead(label: t(".title"), field: :title, errors: @errors, error: FieldError,
                       **title_attributes) do |head|
              head.sub { sub_line }
              head.below { summary_block }
              EditorActions(post: @post, published: published?, scheduling: scheduling?)
            end
          end

          def published? = @post&.status == PUBLISHED

          def read_time = @counts[:read_time]

          def read_time_attributes
            { data: { editor_read_time: t(".read_time"), words_per_minute: ::Posts::Markdown::WORDS_PER_MINUTE } }
          end

          def scheduling? = @preview[:time] > @now

          def slug = ::Posts::Helpers::PostSlug.derive(slug: @values[:slug], title: @values[:title])

          def sub_line
            writing = "#{path(:writing)}/"

            span(data: { editor_path: writing }) { writing + slug }
            plain DOT
            span(data: { editor_words: "", one: t(".words.one"), other: t(".words.other") }) do
              t(".words", count: word_count)
            end
            plain DOT
            span(**read_time_attributes) { t(".read_time", count: read_time) }
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
            { name: "post[title]", value: @values[:title], placeholder: t(".title_placeholder"),
              data: { editor_title: "" } }
          end

          def word_count = @counts[:words]
        end
      end
    end
  end
end
