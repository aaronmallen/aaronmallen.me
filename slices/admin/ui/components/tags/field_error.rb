# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tags
        class FieldError < Blog::UI::FieldError
          SCOPE = "tag"
        end
      end
    end
  end
end
