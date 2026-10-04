# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class FieldError < Blog::UI::FieldError
          SCOPE = "task"
          MESSAGES = {
            body: { "blank" => ".body.blank", "control" => ".body.control" },
            ended_at: {
              "blank" => ".ended_at.blank", "format" => ".ended_at.format", "order" => ".ended_at.order",
              "running" => ".ended_at.running", "skipped" => ".ended_at.skipped",
            },
            hours: { "blank" => ".hours.blank", "format" => ".hours.format" },
            kind: { "format" => ".kind.format" },
            minutes: { "format" => ".minutes.format" },
            other_id: {
              "format" => ".other_id.format", "missing" => ".other_id.missing", "self" => ".other_id.self",
              "taken" => ".other_id.taken",
            },
            started_at: {
              "blank" => ".started_at.blank", "format" => ".started_at.format", "future" => ".started_at.future",
              "skipped" => ".started_at.skipped",
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
