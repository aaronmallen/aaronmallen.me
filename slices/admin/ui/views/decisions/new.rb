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
              BackLink(href: path(:admin_decisions)) { t(".back") }
            end

            Editor(**@editor)
          end
        end
      end
    end
  end
end
