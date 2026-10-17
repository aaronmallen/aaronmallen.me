# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class FieldError < Blog::UI::FieldError
          NOTE = { max: ::Posts::Contracts::PostContract::EDIT_NOTE_LIMIT }.freeze
          LIMITS = { edit_note: NOTE, note: NOTE }.freeze
          SCOPE = "post"
          OVERRIDES = { note: { "long" => ".edit_note.long" } }.freeze
        end
      end
    end
  end
end
