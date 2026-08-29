# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class FieldError < Blog::UI::FieldError
          SCOPE = "social"
          MESSAGES = {
            parts: { "blank" => ".parts.blank", "too_long" => ".parts.too_long" },
            schedule_at: { "format" => ".schedule_at.format", "skipped" => ".schedule_at.skipped" },
            targets: { "blank" => ".targets.blank", "unavailable" => ".targets.unavailable" },
          }.freeze
        end
      end
    end
  end
end
