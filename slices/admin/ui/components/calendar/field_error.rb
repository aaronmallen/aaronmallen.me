# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class FieldError < Blog::UI::FieldError
          SCOPE = "cal-event"
          CONTROL = { "control" => ".control" }.freeze
          OVERRIDES = { place: CONTROL, title: CONTROL }.freeze
        end
      end
    end
  end
end
