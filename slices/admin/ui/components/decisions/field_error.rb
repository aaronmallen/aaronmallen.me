# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class FieldError < Blog::UI::FieldError
          SCOPE = "decision"
          CONTROL = { "control" => ".control" }.freeze
          OVERRIDES = {
            body: CONTROL,
            note: CONTROL,
            option_id: { "format" => ".option_id.missing" },
            problem: CONTROL,
            reason: CONTROL,
            title: CONTROL,
          }.freeze

          def self.field_slug(field) = super.tr("_", "-")
        end
      end
    end
  end
end
