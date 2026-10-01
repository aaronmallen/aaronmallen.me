# frozen_string_literal: true

module Posts
  module Contracts
    class EditNoteContract < Blog::Contract
      params do
        required(:note).value(Blog::Types::TrimmedText, :filled?, max_size?: PostContract::EDIT_NOTE_LIMIT)
      end

      rule(:note).validate(:without_controls)
    end
  end
end
