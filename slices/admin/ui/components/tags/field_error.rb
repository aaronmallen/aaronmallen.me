# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tags
        class FieldError < Blog::UI::FieldError
          SCOPE = "tag"
          MESSAGES = {
            color: { "format" => ".color.format" },
            name: { "blank" => ".name.blank", "format" => ".name.format", "taken" => ".name.taken" },
          }.freeze
        end
      end
    end
  end
end
