# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class New < View
          include Components::Tasks

          SCOPE = "new"

          prop :errors, Blog::Types::Hash
          prop :values, Blog::Types::Hash
          prop :origin, Blog::Types::TaskOrigin

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub")) { BackLink(origin: @origin) }

            Card(label: t(".label"), title: t(".title")) do
              TaskForm(
                errors: @errors, returns: { origin: @origin }, scope: SCOPE, today: Blog::TimeZone.today,
                values: @values, autofocus: true,
              )
            end
          end
        end
      end
    end
  end
end
