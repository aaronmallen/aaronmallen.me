# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class FieldError < Blog::UI::FieldError
          SCOPE = "task"

          def self.field_slug(field) = super.tr("_", "-")
        end
      end
    end
  end
end
