# frozen_string_literal: true

module Notes
  module Contracts
    class NoteContract < Blog::Contract
      BODY_LIMIT = 100_000
      TITLE_LIMIT = 200

      params do
        optional(:title).filled(Blog::Types::TrimmedText, max_size?: TITLE_LIMIT)
        optional(:body).value(Blog::Types::Normalized::Breaks, max_size?: BODY_LIMIT)
        optional(:folder_id).maybe(Blog::Types::Id)
        optional(:tags).value(Blog::Types::TagList)
        optional(:version).filled(Blog::Types::Id)
      end

      rule(:title).validate(:without_controls, :visible)
      rule(:body).validate(:without_controls)
      rule(:tags).validate(:tag_slugs)
    end
  end
end
