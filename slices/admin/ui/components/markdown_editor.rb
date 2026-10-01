# frozen_string_literal: true

module Admin
  module UI
    module Components
      class MarkdownEditor < Component
        HEIGHT = Blog::Types::String.constrained(format: /\A\d+(?:\.\d+)?(?:px|rem)\z/)
        PREVIEW = "preview"
        TOOLS = [
          [".tools.h2", ".tools.h2_label", "\n\n## "],
          [".tools.bold", ".tools.bold_label", "**bold**"],
          [".tools.italic", ".tools.italic_label", "*italic*"],
          [".tools.code", ".tools.code_label", "\n\n```ruby\n\n```"],
          [".tools.quote", ".tools.quote_label", "\n\n> "],
        ].freeze
        WRITE = "write"
        VIEWS = [WRITE, PREVIEW].freeze

        prop :name, Blog::Types::String
        prop :value, Blog::Types::String
        prop :height, HEIGHT
        prop :renderer, Blog::Types::MarkdownRenderer
        prop :id, Blog::Types::String
        prop :label, Blog::Types::String
        prop :placeholder, Blog::Types::String.optional, default: nil
        prop :preview_path, Blog::Types::String.optional, default: nil
        prop :view, Blog::Types::String.optional, default: nil
        prop :view_name, Blog::Types::String.optional, default: nil
        prop :attributes, Blog::Types::Hash, :**

        def view_template(&)
          div(class: "edit", style: "--edit-height: #{@height}", data: { markdown_editor: "" }) do
            pane_head
            write_pane
            preview_pane(&)
          end
        end

        private

        def body_attributes
          own = { id: @id, class: "edit-body", name: @name, placeholder: @placeholder, data: { editor_body: "" } }
          mix(own, @attributes)
        end

        def pane_head
          div(class: "edit-pane-head") do
            SegmentedControl(label: t(".view"), name: view_name, options: view_options, selected:)
            toolbar
          end
        end

        def preview_data
          return { editor_preview: @preview_path, editor_preview_form: "" } if @preview_path

          { editor_preview: path(:admin_preview_markdown, renderer: @renderer) }
        end

        def preview_pane(&)
          div(class: "edit-pane", data: { editor_view: PREVIEW }, hidden: selected != PREVIEW) do
            div(class: "preview", data: preview_data, &)
          end
        end

        def selected = VIEWS.include?(@view) ? @view : WRITE

        def toolbar
          div(**toolbar_attributes) do
            TOOLS.each do |(text_key, label_key, snippet)|
              button(class: "toolbar-button", type: "button", aria: { label: t(label_key) }, data: { snippet: }) do
                t(text_key)
              end
            end
          end
        end

        def toolbar_attributes
          { class: "toolbar", role: "toolbar", aria: { label: t(".toolbar") },
            data: { editor_view: WRITE }, hidden: selected != WRITE }
        end

        def view_name = @view_name || "#{@id}-view"

        def view_options = { WRITE => t(".write"), PREVIEW => t(".preview") }

        def write_pane
          div(class: "edit-pane", data: { editor_view: WRITE }, hidden: selected != WRITE) do
            label(class: "sr-only", for: @id) { @label }
            textarea(**body_attributes) { @value }
          end
        end
      end
    end
  end
end
