# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class FieldError < Blog::UI::FieldError
          SCOPE = "project"
        end
      end
    end
  end
end
