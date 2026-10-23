# frozen_string_literal: true

module Blog
  module UI
    module Components
      class TaskFilter < Component
        ID = "task-filter"
        QUALIFIERS = {
          "label:" => ".qualifiers.label", "-label:" => ".qualifiers.not_label", "no:label" => ".qualifiers.no_label",
          "is:open" => ".qualifiers.open", "is:closed" => ".qualifiers.closed", "is:doing" => ".qualifiers.doing",
          "is:blocked" => ".qualifiers.blocked", "column:" => ".qualifiers.column",
        }.freeze

        prop :action, Blog::Types::String
        prop :name, Blog::Types::String
        prop :text, Blog::Types::String
        prop :ignored, Blog::Types::Array.of(Blog::Types::String), default: Blog::Constants::EMPTY_ARRAY
        prop :shown, Blog::Types::Integer
        prop :total, Blog::Types::Integer.optional, default: nil
        prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :columns, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::String)
        prop :form, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

        def view_template
          div(class: "task-filter", data: { task_filter: JSON.generate(choices) }) do
            div(class: "task-filter-row") do
              box
              yield if block_given?
            end
            meta if written?(@text)
          end
        end

        private

        def box
          Form(method: Form::GET, action: @action, role: "search", class: "task-filter-box", **@form) do
            Icon("fa-solid fa-magnifying-glass")
            field
            clear if written?(@text)
            div(id: "#{ID}-list", class: "task-filter-list", role: "listbox", aria: { label: t(".suggestions") },
                hidden: true)
          end
        end

        def choices
          {
            qualifiers: QUALIFIERS.map { |term, key| [term, t(key)] },
            tags: @tags.map { [it.name, it.description, Pill.for_tag_color(it.color)] },
            columns: @columns.to_a,
          }
        end

        def clear
          Button(href: @action, variant: :gh, small: true, icon: :close, label: t(".clear"))
        end

        def field
          input(
            id: ID, class: "task-filter-input", type: "text", name: "q", value: @text, role: "combobox",
            placeholder: t(".placeholder"), spellcheck: "false", autocomplete: "off",
            aria: { label: t(".label", name: @name), expanded: "false", controls: "#{ID}-list", autocomplete: "list" },
          )
        end

        def ignored
          span(class: "task-filter-ignored") do
            Icon("fa-solid fa-triangle-exclamation")
            plain t(".ignored", terms: @ignored.join(" "))
          end
        end

        def meta
          p(class: "task-filter-meta") do
            span { t(".match", shown: @shown, count: @total || @shown) }
            ignored if @ignored.any?
            a(href: @action, class: "task-filter-clear") { t(".clear_filter") }
          end
        end
      end
    end
  end
end
