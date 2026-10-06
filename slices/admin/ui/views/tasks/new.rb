# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class New < View
          include Components::Tasks

          FROM_TODAY = Blog::Types::TaskOrigin["today"]
          SCOPE = "new"

          def initialize(errors:, values:, origin:)
            super()
            @errors = errors
            @values = values
            @origin = origin
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub")) { back }

            Card(label: t(".label"), title: t(".title")) do
              TaskForm(
                errors: @errors, returns: { origin: @origin }, scope: SCOPE, today: Blog::TimeZone.today,
                values: @values, autofocus: true,
              )
            end
          end

          private

          def back
            BackLink(href: back_path) { t(today? ? ".back_today" : ".back_tasks") }
          end

          def back_path = today? ? path(:admin_root) : path(:admin_tasks)

          def today? = @origin == FROM_TODAY
        end
      end
    end
  end
end
