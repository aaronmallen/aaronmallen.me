# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class MoveForm < Component
          MOVES = {
            post: :admin_move_calendar_post,
            social: :admin_move_calendar_social_post,
            task: :admin_move_calendar_task,
          }.freeze

          prop :kind, Blog::Types::Symbol.enum(*MOVES.keys)
          prop :id, Blog::Types::Integer
          prop :title, Blog::Types::String
          prop :date, Blog::Types::Date
          prop :today, Blog::Types::Date

          def view_template
            Form(action: path(MOVES.fetch(@kind), id: @id), class: "cal-move") do
              grip
              input(type: "hidden", name: "day", value: @date.iso8601)
              label(class: "sr-only", for: field) { t(".move_to", title: @title) }
              Input(type: "date", id: field, name: "to", min: @today.iso8601, value: @date.iso8601)
              Button(type: "submit", small: true) { t(".move") }
            end
          end

          private

          def field = "cal-move-#{@kind}-#{@id}"

          def grip
            Button(
              small: true, class: "cal-grip", hidden: true, label: t(".drag", title: @title), data: grip_data,
              icon: "fa-solid fa-grip-vertical",
            )
          end

          def grip_data
            { calendar_grip: "", calendar_failed: t(".failed"), calendar_past: t("calendar_page.toasts.past") }
          end
        end
      end
    end
  end
end
