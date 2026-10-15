# frozen_string_literal: true

module Admin
  module UI
    module Components
      class BulkBar < Component
        ACT = "act"
        FIELD = "ids[]"

        prop :id, Blog::Types::String
        prop :action, Blog::Types::String
        prop :label, Blog::Types::String
        prop :fields, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
        prop :menu, Blog::Types::String.optional, default: nil
        prop :all, Blog::Types::String.optional, default: nil
        prop :hint, Blog::Types::String.optional, default: nil
        prop :toggled, Blog::Types::Bool, default: false

        def act(value, icon:, label:, variant: nil, data: nil)
          Button(type: "submit", variant:, small: true, name: ACT, value:, data:, icon:) { label }
        end

        def choose(name, act, prompt:, options:, icon:, label:)
          div(class: "bulk-group") do
            Select(
              name:, class: "bulk-field", aria: { label: prompt }, options: { "" => prompt, **options }, selected: "",
              data: { bulk_choose: true },
            )
            act(act, icon:, label:)
          end
        end

        def tagging(tag:, untag: nil)
          @tag = tag
          div(class: "bulk-group") do
            Input(name: "tag", class: "bulk-field", autocomplete: "off", placeholder: t(".tag_placeholder"),
                  aria: { label: t(".tag_name") })
            act(tag, icon: "fa-solid fa-tag", label: t(".tag"))
            act(untag, icon: :close, label: t(".untag")) if untag
          end
        end

        def view_template(&)
          vanish(&)

          Form(id: @id, action: @action, class: "bulk-bar", aria: { label: @label }, data: form_data) do
            HiddenFields(values: @fields)
            all
            span(class: "bulk-count", aria: { live: "polite" }, data: { bulk_count: t(".ticked") })
            div(class: "bulk-acts", data: { bulk_acts: true }) do
              button(type: "submit", name: ACT, value: @tag, hidden: true, tabindex: "-1") if @tag
              yield(self)
            end
          end
        end

        private

        def all
          label(class: "choice", hidden: true, data: { bulk_all: true }) do
            input(type: "checkbox", class: "check", autocomplete: "off")
            span { @all || t(".all") }
            span(class: "bulk-hint") { @hint } if @hint
          end
        end

        def form_data = { bulk: FIELD, bulk_menu: @menu, bulk_off: @toggled }
      end
    end
  end
end
