# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Decisions
        class New < View
          include Components::Decisions

          def initialize(**editor)
            super()
            @editor = editor
          end

          def view_template
            PageHead(title: t(".heading")) do
              a(class: "btn", href: path(:admin_decisions)) do
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
