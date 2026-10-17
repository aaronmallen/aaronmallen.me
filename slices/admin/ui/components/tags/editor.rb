# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tags
        class Editor < Component
          LAST_SEPARATOR = " and "
          LIST_SEPARATOR = ", "
          PANEL_ID = "tag-panel"
          SCOPES = Blog::Types::TagScope.values.to_h { [it, "ui.views.tags.index.scopes.#{it}"] }.freeze

          prop :tag, Blog::Types::Instance(ROM::Struct)
          prop :uses, Blog::Types::Hash
          prop :editing, Blog::Types::Hash.optional, default: nil
          prop :page, Blog::Types::Integer, default: 1
          prop :query, Blog::Types::String, default: ""

          def self.id_for(tag) = "tag-#{tag.id}-editor"

          def view_template
            Card(
              as: :div, note: t(SCOPES.fetch(@tag.scope)), note_class: "meta",
              class: ["tag-editor", ("tag-editor-open" if editing?)], id: self.class.id_for(@tag),
            ) do |card|
              card.heading { Tag(tag: @tag) }
              rename_form
              FieldError(field: :name, errors:, scope:)
              color_form
              foot
            end
          end

          private

          def cancel = a(class: "bt sm gh", href: "##{PANEL_ID}") { t(".cancel") }

          def color_form
            Form(action: path(:admin_update_tag, id: @tag.id), class: "field") do
              return_fields
              input(type: "hidden", name: "tag[name]", value: @tag.name)
              span(class: "f") { t(".color") }
              Swatches(name: "tag[color]", scope:, selected: @tag.color, submit: true)
            end
          end

          def counts = Row::USE_KEYS.filter_map { |kind, key| t(key, count: @uses[kind]) if @uses[kind] }

          def description = editing? ? @editing.fetch(:description) { @tag.description } : @tag.description

          def description_field
            label(class: "f", for: description_id) { t(".description") }
            Textarea(id: description_id, name: "tag[description]", rows: 3, value: description)
            Hint { t(".description_hint") }
          end

          def description_id = "tag-#{@tag.id}-description"

          def editing? = @editing&.fetch(:id) == @tag.id

          def errors = editing? ? @editing[:errors] : Blog::Constants::EMPTY_HASH

          def foot
            div(class: "tag-editor-foot") do
              save
              cancel
              remove
            end
          end

          def held = @uses.values.sum

          def losers
            *rest, last = counts

            rest.empty? ? last : [rest.join(LIST_SEPARATOR), last].join(LAST_SEPARATOR)
          end

          def name = editing? ? @editing[:name] : @tag.name

          def remove
            DeleteForm(
              action: path(:admin_delete_tag, id: @tag.id), label: t(".remove"),
              confirm: t(".confirm_remove", tag: @tag.name, count: held, uses: losers),
            ) do
              return_fields
            end
          end

          def rename_form
            Form(action: path(:admin_update_tag, id: @tag.id), class: "field", id: rename_id) do
              return_fields
              label(class: "f", for: FieldError.id_for(:name, scope)) { t(".rename") }
              Input(**FieldError.control_attributes(:name, errors, scope), name: "tag[name]", value: name)
              description_field
            end
          end

          def rename_id = "tag-#{@tag.id}-form"

          def return_fields
            HiddenFields(values: { scope: @tag.scope, page: (@page if @page > 1), q: (@query unless @query.empty?) })
          end

          def save
            Button(variant: :pri, type: "submit", small: true, form: rename_id, icon: :save) do
              t(".save")
            end
          end

          def scope = "tag-#{@tag.id}"
        end
      end
    end
  end
end
