# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class New < View
          include Components::Tasks

          SCOPE = "new"

          def initialize(errors:, values:)
            super()
            @errors = errors
            @values = values
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub")) { back }

            Card(label: t(".label"), title: t(".title")) do
              CreateForm(errors: @errors, scope: SCOPE, today: Blog::TimeZone.today, values: @values, autofocus: true)
            end
          end

          private

          def back
            a(class: "btn", href: path(:admin_tasks)) do
              i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
              span { t(".back") }
            end
          end
        end
      end
    end
  end
end
