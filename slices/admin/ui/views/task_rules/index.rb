# frozen_string_literal: true

module Admin
  module UI
    module Views
      module TaskRules
        class Index < View
          include Components::TaskRules

          BLANK = {
            errors: Blog::Constants::EMPTY_HASH,
            pattern: Blog::Constants::EMPTY_STRING,
            provider: Blog::Types::TaskSourceProvider["github"],
            tags: Blog::Constants::EMPTY_STRING,
            projects: Blog::Constants::EMPTY_ARRAY,
          }.freeze
          TYPED = %i[pattern provider tags].freeze

          prop :adding, Blog::Types::Hash
          prop :editing, Blog::Types::Hash.optional
          prop :rules, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :projects, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def self.typed(params)
            { **TYPED.to_h { [it, Blog::Types::Text[params[it]]] }, projects: Array(params[:projects]).map(&:to_s) }
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @rules.size)) { back }
            Card(label: t(".label"), title: t(".title"), data: { key_list: true }) do |card|
              card.side { Hint(inline: true) { t(".aside") } }
              Capture(**@adding, choices: @projects)
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

            @rules.each { Row(rule: it, editing: @editing, choices: @projects) }
          end
        end
      end
    end
  end
end
