# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class FieldError < Blog::UI::FieldError
          SCOPE = "person"
        end
      end
    end
  end
end
