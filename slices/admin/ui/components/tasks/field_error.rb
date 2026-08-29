# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class FieldError < Blog::UI::FieldError
          SCOPE = "task"
          MESSAGES = {
            color: { "format" => ".color.format" },
            icon: { "format" => ".icon.format" },
            kind: { "format" => ".kind.format" },
            name: { "blank" => ".name.blank", "taken" => ".name.taken" },
            other_id: {
              "format" => ".other_id.format", "missing" => ".other_id.missing", "self" => ".other_id.self",
              "taken" => ".other_id.taken",
            },
            tags: { "format" => ".tags.format" },
            task_type_id: { "format" => ".task_type_id.format" },
            title: { "blank" => ".title.blank" },
          }.freeze

          def self.field_slug(field) = super.tr("_", "-")
        end
      end
    end
  end
end
