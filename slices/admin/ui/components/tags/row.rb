# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tags
        class Row < Component
          KINDS = %i[posts projects journal_entries tasks decisions task_rules].freeze
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
            a(class: "bt sm tag-pen", href: "##{Editor.id_for(@tag)}", title: t(".edit")) do
              Icon("fa-regular fa-pen-to-square")
              span(class: "sr-only") { t(".edit") }
            end
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
