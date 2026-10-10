# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class FieldError < Blog::UI::FieldError
          SCOPE = "social"
        end
      end
    end
  end
end
