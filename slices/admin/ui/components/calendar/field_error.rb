# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::Calendar::Contracts::EventContract].freeze
          SCOPE = "cal-event"
        end
      end
    end
  end
end
