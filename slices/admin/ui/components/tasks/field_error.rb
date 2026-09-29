# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class FieldError < Blog::UI::FieldError
          SCOPE = "task"
          MESSAGES = {
            kind: { "format" => ".kind.format" },
            other_id: {
              "format" => ".other_id.format", "missing" => ".other_id.missing", "self" => ".other_id.self",
              "taken" => ".other_id.taken",
            },
            tags: { "format" => ".tags.format" },
            title: { "blank" => ".title.blank" },
          }.freeze

          def self.field_slug(field) = super.tr("_", "-")
        end
      end
    end
  end
end
