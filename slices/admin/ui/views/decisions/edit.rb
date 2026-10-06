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
              BackLink(href: path(:admin_decision, id: decision.id)) { t(".back") }
            end

            Editor(**@editor)
          end
        end
      end
    end
  end
end
