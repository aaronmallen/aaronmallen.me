# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [::Posts::Contracts::EditNoteContract, ::Posts::Contracts::PostContract].freeze
          NOTE = { max: ::Posts::Contracts::PostContract::EDIT_NOTE_LIMIT }.freeze
          LIMITS = { edit_note: NOTE, note: NOTE }.freeze
          SCOPE = "post"
          UNSHOWN = %i[syndication_targets].freeze
          OVERRIDES = { canonical_url: URL, note: { "long" => ".edit_note.long" }, og_image_url: URL }.freeze
        end
      end
    end
  end
end
