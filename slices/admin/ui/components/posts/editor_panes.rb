# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class EditorPanes < Component
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

          prop :values, Blog::Types::Hash
          prop :preview, Blog::Types::Hash
          prop :view, Blog::Types::String.optional

          def view_template
            div(class: "edit") do
              pane_head
              write_pane
              preview_pane
            end
          end

          private

          def body_attributes
            { id: "post-body", class: "edit-body", name: "post[body]", placeholder: t(".placeholder"),
              data: { editor_body: "" } }
          end

          def pane_head
            div(class: "edit-pane-head") do
              SegmentedControl(label: t(".view"), name: "view", options: view_options, selected:)
              toolbar
            end
          end

          def preview_pane
            div(class: "edit-pane", data: { editor_view: PREVIEW }, hidden: selected != PREVIEW) do
              div(class: "preview", data: { editor_preview: path(:admin_preview_post) }) do
                Preview(**@preview)
              end
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

          def view_options = { WRITE => t(".write"), PREVIEW => t(".preview") }

          def write_pane
            div(class: "edit-pane", data: { editor_view: WRITE }, hidden: selected != WRITE) do
              label(class: "sr-only", for: "post-body") { t(".body") }
              textarea(**body_attributes) { @values[:body] }
            end
          end
        end
      end
    end
  end
end
