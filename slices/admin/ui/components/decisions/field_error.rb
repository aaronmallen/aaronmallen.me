# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class FieldError < Blog::UI::FieldError
          SCOPE = "decision"
          MESSAGES = {
            body: { "control" => ".control" },
            note: { "blank" => ".note.blank", "control" => ".control", "long" => ".note.long" },
            option_id: { "format" => ".option_id.missing", "missing" => ".option_id.missing" },
            problem: { "blank" => ".problem.blank", "control" => ".control" },
            reason: { "blank" => ".reason.blank", "control" => ".control" },
            tags: { "format" => ".tags.format" },
            title: { "blank" => ".title.blank", "control" => ".control" },
          }.freeze

          def self.field_slug(field) = super.tr("_", "-")
        end
      end
    end
  end
end
