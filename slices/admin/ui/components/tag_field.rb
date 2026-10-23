# frozen_string_literal: true

module Admin
  module UI
    module Components
      class TagField < Component
        NAME = "{name}"

        prop :control, Blog::Types::Hash
        prop :name, Blog::Types::String
        prop :value, Blog::Types::String
        prop :placeholder, Blog::Types::String
        prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)).optional, default: nil
        prop :project, Blog::Types::Integer.optional, default: nil
        prop :src, Blog::Types::String.optional, default: nil

        def self.choices(tags)
          tags.map { { name: it.name, color: Blog::UI::Components::Pill.for_tag_color(it.color)&.to_s } }
        end

        def view_template
          Input(**@control, name: @name, value: @value, placeholder: @placeholder, data: { tag_field_value: "" })
          div(class: "tag-pick", hidden: true, data: pick_data) do
            ul(class: "tag-pick-chips", aria: { label: t(".chosen") }, data: { tag_field_chips: "" })
            Input(**mix(@control.except(:id), search_attributes))
            div(
              id: list_id, class: "tag-pick-results", role: "listbox", hidden: true,
              aria: { label: t(".tags") }, data: { tag_field_results: "" },
            )
            p(class: "sr-only", role: "status", data: { tag_field_status: "" })
          end
        end

        private

        def list_id = "#{@control[:id]}-results"

        def pick_data
          {
            tag_field: @tags ? JSON.generate(self.class.choices(@tags)) : "",
            tag_field_src: (@src || path(:admin_private_tag_choices, **{ project: @project }.compact) unless @tags),
            tag_field_add: t(".add", name: NAME),
            tag_field_none: t(".no_match"),
            tag_field_remove: t(".remove", name: NAME),
            tag_field_results_one: t(".results.one"),
            tag_field_results_other: t(".results.other"),
          }
        end

        def search_attributes
          {
            id: "#{@control[:id]}-search", autocomplete: "off", role: "combobox", placeholder: @placeholder,
            aria: { autocomplete: "list", controls: list_id, expanded: "false" },
            data: { tag_field_input: "" },
          }
        end
      end
    end
  end
end
