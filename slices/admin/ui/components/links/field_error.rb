# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Links
        class FieldError < Blog::UI::FieldError
          SCOPE = "link"
        end
      end
    end
  end
end
