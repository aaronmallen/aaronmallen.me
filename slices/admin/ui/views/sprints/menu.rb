# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Sprints
        class Menu < View
          layout nil

          prop :sprint, Blog::Types::Instance(ROM::Struct)

          def view_template
            date = @sprint.sprint_date

            ContextMenu(label: t(".label", date: l(date, format: :medium))) do |menu|
              menu.link(t(".calendar"), href: path(:admin_calendar, day: date.iso8601), icon: "fa-regular fa-calendar")
              menu.separator
              menu.post(t(".drop"), action: path(:admin_drop_sprint, id: @sprint.id), icon: :trash,
                                    warn: true, confirm: t(".confirm_drop"))
            end
          end
        end
      end
    end
  end
end
