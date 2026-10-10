# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Row < Component
          prop :decision, Blog::Types::Instance(ROM::Struct)

          def view_template
            div(class: "decision-row", data: { key_row: true }) do
              RecordKey(kind: "decision", id: @decision.id)
              div(class: "decision-row-body") do
                a(class: "decision-row-title", href: path(:admin_decision, id: @decision.id),
                  data: { key_open: true }) do
                  @decision.title
                end
                p(class: "decision-meta") { meta }
              end
              StatusPill(status: @decision.status)
            end
          end

          private

          def chosen
            option = @decision.options.find { it.id == @decision.resolved_option_id }
            return unless option

            span(class: "decision-chosen") { IconLabel(icon: "fa-solid fa-check") { option.title } }
          end

          def comments
            count = @decision.comments.size
            return if count.zero?

            span do
              Icon("fa-regular fa-comment")
              plain count.to_s
              whitespace
              span(class: "sr-only") { t(".comments", count:) }
            end
          end

          def meta
            span { Stamped(text: t(".opened", date: Stamped::MARK), at: @decision.created_at, format: :day) }
            span { t(".options", count: @decision.options.size) }
            chosen
            comments
            @decision.tags.each { Tag(tag: it) }
          end
        end
      end
    end
  end
end
