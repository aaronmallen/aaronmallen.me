# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tags
        class Row < Component
          KINDS = %i[posts projects journal_entries tasks decisions task_rules messages].freeze
          USE_KEYS = KINDS.to_h { [it, "ui.components.tags.row.uses.#{it}"] }.freeze

          prop :tag, Blog::Types::Instance(ROM::Struct)
          prop :uses, Blog::Types::Hash

          def view_template
            div(class: "tag-row", data: { key_row: true }) do
              p(class: "tag-name") { Tag(tag: @tag) }
              p(class: "tag-uses") { uses }
              div(class: "tag-acts") { edit }
            end
          end

          private

          def counts = USE_KEYS.filter_map { |kind, key| t(key, count: @uses[kind]) if @uses[kind] }

          def edit
            Button(
              href: "##{Editor.id_for(@tag)}", small: true, class: "tag-pen", label: t(".edit"),
              icon: "fa-regular fa-pen-to-square",
            )
          end

          def uses
            return t(".unused") if @uses.values.sum.zero?

            dotted(*counts)
          end
        end
      end
    end
  end
end
