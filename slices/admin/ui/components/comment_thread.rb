# frozen_string_literal: true

module Admin
  module UI
    module Components
      class CommentThread < Component
        EDITOR_HEIGHT = "120px"
        RENDERER = Blog::Types::MarkdownRenderer["tasks"]
        ROUTES = Blog::Types::Hash.schema(
          create: Blog::Types::Symbol, update: Blog::Types::Symbol, delete: Blog::Types::Symbol,
        )

        prop :record_id, Blog::Types::Integer
        prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :routes, ROUTES
        prop :scope, Blog::Types::String
        prop :form, Blog::Types::Hash
        prop :error, Blog::Types::Instance(Class)

        def author(&block)
          @author = block
          nil
        end

        def event(&block)
          @event = block
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

          ol(class: "timeline") { @entries.each { entry(it) } } unless @entries.empty?
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
          Form(action: path(@routes[:create], id: @record_id), class: "stack-form") do
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
            MarkdownEditor(**@error.control_attributes(:body, errors, scope), **editor_props(label, value))
            render @error.new(field: :body, errors:, scope:)
          end
        end

        def comment(comment)
          id = comment.source_id

          li(class: "comment", id: "#{@scope}-comment-#{id}", data: { "#{@scope}_comment": id }) do
            head(comment)
            div(class: "markdown-body post-body comment-body") do
              raw(safe(::Tasks::Markdown.to_html(comment.body).strip))
            end
          end
        end

        def comment_route(name, comment) = path(@routes[name], id: @record_id, comment_id: comment.source_id)

        def delete_form(comment)
          label = t(".delete")
          data = { confirm: t(".confirm_delete"), confirm_styled: true }

          Form(action: comment_route(:delete, comment), data:) do
            @fields&.call
            Button(
              type: "submit", variant: :gh, small: true, title: label, aria: { label: },
              icon: "fa-regular fa-trash-can",
            )
          end
        end

        def edit_form(comment)
          details(class: "comment-edit", open: mine?(comment.source_id)) do
            summary(class: "btn sm") { t(".edit") }
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

        def entry(entry) = entry.comment? ? comment(entry) : @event&.call(entry)

        def head(comment)
          div(class: "comment-head") do
            span(class: "comment-author") do
              comment.synced? ? @author&.call(comment) : plain(Hanami.app.settings.owner_name)
            end
            Moment(at: comment.occurred_at, class: "timeline-time")
            comment.synced? ? @source&.call(comment) : acts(comment)
          end
        end

        def mine?(id) = @form.key?(:id) && @form[:id] == id
      end
    end
  end
end
