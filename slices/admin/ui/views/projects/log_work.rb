# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Projects
        class LogWork < View
          include Components::WorkEntries

          SCOPE = "work-log"

          def initialize(errors:, values:, return_to:)
            super()
            @errors = errors
            @values = values
            @return_to = return_to
          end

          def view_template
            content_for(:title, t(".heading"))
            PageHead(title: t(".heading"), sub: t(".sub"))

            Card(label: t(".label"), title: t(".title")) do
              Fields(errors: @errors, values: @values, scope: SCOPE, returns: { return_to: @return_to }) { back }
            end
          end

          private

          def back
            a(class: "btn sm", href: @return_to, data: { dialog_close: true }) { t(".cancel") }
          end
        end
      end
    end
  end
end
