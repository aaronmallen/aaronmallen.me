# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class FieldError < Blog::UI::FieldError
          SCOPE = "post"
          OVERRIDES = { note: { "control" => ".edit_note.control", "long" => ".edit_note.long" } }.freeze
        end
      end
    end
  end
end
