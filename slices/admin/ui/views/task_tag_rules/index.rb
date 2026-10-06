# frozen_string_literal: true

module Admin
  module UI
    module Views
      module TaskTagRules
        class Index < View
          include Components::TaskTagRules

          BLANK = {
            errors: Blog::Constants::EMPTY_HASH,
            pattern: Blog::Constants::EMPTY_STRING,
            provider: Blog::Types::TaskSourceProvider["github"],
            tags: Blog::Constants::EMPTY_STRING,
          }.freeze
          TYPED = %i[pattern provider tags].freeze

          def initialize(adding:, editing:, rules:)
            super()
            @adding = adding
            @editing = editing
            @rules = rules
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @rules.size)) { back }
            Card(label: t(".label"), title: t(".title"), data: { key_list: true }) do |card|
              card.side { Hint(inline: true) { t(".aside") } }
              Capture(**@adding)
              rows
            end
            Hint { t(".note") }
          end

          private

          def back
            a(class: "btn", href: path(:admin_tasks, filter: Blog::Types::TaskTab["external"])) do
              i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
              span { t(".back") }
            end
          end

          def rows
            return Empty { t(".empty") } if @rules.empty?

            @rules.each { Row(rule: it, editing: @editing) }
          end
        end
      end
    end
  end
end
