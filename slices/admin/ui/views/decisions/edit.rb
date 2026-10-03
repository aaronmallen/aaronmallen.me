# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Decisions
        class Edit < View
          include Components::Decisions

          def initialize(**editor)
            super()
            @editor = editor
          end

          def view_template
            decision = @editor[:decision]

            PageHead(title: decision.title, kicker: t(".kicker")) do
              a(class: "btn", href: path(:admin_decision, id: decision.id)) do
                i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
                span { t(".back") }
              end
            end

            Editor(**@editor)
          end
        end
      end
    end
  end
end
