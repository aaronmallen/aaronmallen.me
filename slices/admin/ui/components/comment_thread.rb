# frozen_string_literal: true

module Admin
  module UI
    module Components
      class CommentThread < Component
        EDITOR_HEIGHT = "120px"
        RENDERER = Blog::Types::MarkdownRenderer["tasks"]
        ROUTES = Blog::Types::Hash.schema(
          create: Blog::Types::Symbol, update: Blog::Types::Symbol, delete: Blog::Types::Symbol,
          menu: Blog::Types::Symbol,
        )

        prop :record_id, Blog::Types::Integer
        prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :routes, ROUTES
        prop :scope, Blog::Types::String
        prop :form, Blog::Types::Hash
        prop :error, Blog::Types::Instance(Class)
        prop :edited, Blog::Types::Array.of(Blog::Types::Integer), default: Blog::Constants::EMPTY_ARRAY

        include Deps["settings"]

        def author(&block)
          @author = block
          nil
        end

        def fields(&block)
          @fields = block
          nil
        end

        def source(&block)
          @source = block
          nil
        end

        def view_template(&)
          vanish(&)

          ol(class: "timeline") { @entries.each { comment(it) } } unless @entries.empty?
          add_form
        end

        private

        def acts(comment)
          div(class: "comment-acts") do
            edit_form(comment)
            delete_form(comment)
          end
        end

        def add_form
          Form(action: path(@routes[:create], id: @record_id), class: "stack-form", data: { comment_add: true }) do
            @fields&.call
            body_field(nil, t(".add_label"))
            Button(variant: :pri, type: "submit", small: true) { t(".add") }
          end
        end

        def body_field(id, label, saved = nil)
          scope = ["#{@scope}-#{@record_id}-comment", id].compact.join("-")
          errors = mine?(id) ? @form[:errors] : Blog::Constants::EMPTY_HASH
          value = mine?(id) ? @form[:body] : saved

          Field(label:) do
            MarkdownEditor(field: :body, errors:, error: @error, scope:, **editor_props(label, value))
          end
        end

        def comment(comment)
          id = comment.source_id

          li(class: "comment", id: "#{@scope}-comment-#{id}", data: { "#{@scope}_comment": id, menu: menu(id) }) do
            head(comment)
            MarkdownBody(source: comment.body, markdown: ::Tasks::Markdown, class: "markdown-body comment-body")
          end
        end

        def comment_route(name, comment) = path(@routes[name], id: @record_id, comment_id: comment.source_id)

        def delete_form(comment)
          label = t(".delete")
          data = { morph: true, confirm: t(".confirm_delete") }

          Form(action: comment_route(:delete, comment), data:) do
            @fields&.call
            Button(
              type: "submit", variant: :gh, small: true, label:, icon: "fa-regular fa-trash-can",
            )
          end
        end

        def edit_form(comment)
          details(class: "comment-edit", open: mine?(comment.source_id)) do
            summary(class: "bt sm") { t(".edit") }
            Form(action: comment_route(:update, comment)) do
              @fields&.call
              body_field(comment.source_id, t(".edit_label"), comment.body)
              Button(variant: :pri, type: "submit", small: true) { t(".save") }
            end
          end
        end

        def editor_props(label, value)
          { name: "comment[body]", value: value.to_s, height: EDITOR_HEIGHT, renderer: RENDERER, label: }
        end

        def head(comment)
          div(class: "comment-head") do
            span(class: "comment-author") do
              comment.synced? ? @author&.call(comment) : plain(settings.owner_name)
            end
            Moment(at: comment.occurred_at, class: "timeline-time")
            span(class: "comment-edited") { t(".edited") } if @edited.include?(comment.source_id)
            comment.synced? ? @source&.call(comment) : acts(comment)
          end
        end

        def menu(id) = path(@routes[:menu], id: @record_id, comment_id: id)

        def mine?(id) = @form.key?(:id) && @form[:id] == id
      end
    end
  end
end
