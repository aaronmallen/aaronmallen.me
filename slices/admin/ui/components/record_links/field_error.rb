# frozen_string_literal: true

module Admin
  module UI
    module Components
      module RecordLinks
        class FieldError < Blog::UI::FieldError
          SCOPE = "record"
          MESSAGES = {
            other_id: {
              "format" => ".other_id.format", "missing" => ".other_id.missing", "self" => ".other_id.self",
              "task_pair" => ".other_id.task_pair", "taken" => ".other_id.taken",
            },
            other_kind: { "format" => ".other_kind.format" },
          }.freeze

          def self.field_slug(field) = super.tr("_", "-")
        end
      end
    end
  end
end
