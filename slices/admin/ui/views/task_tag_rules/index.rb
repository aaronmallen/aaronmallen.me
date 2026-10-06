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

          prop :adding, Blog::Types::Hash
          prop :editing, Blog::Types::Hash.optional
          prop :rules, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

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
            BackLink(href: path(:admin_tasks, filter: Blog::Types::TaskTab["external"])) { t(".back") }
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
