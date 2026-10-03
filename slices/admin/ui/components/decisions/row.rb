# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Row < Component
          SEPARATOR = " · "

          prop :decision, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: @decision.title, href: path(:admin_decision, id: @decision.id), sub:)
          end

          private

          def sub
            [
              t(".options", count: @decision.options.size),
              t(".opened", date: l(Blog::TimeZone.local(@decision.created_at), format: :medium)),
            ].join(SEPARATOR)
          end
        end
      end
    end
  end
end
