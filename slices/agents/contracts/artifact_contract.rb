# frozen_string_literal: true

module Agents
  module Contracts
    class ArtifactContract < ArtifactVersionContract
      BODY_LIMIT = 100_000
      TITLE_LIMIT = 200

      params(AUTHOR, NOTE) do
        required(:title).filled(Blog::Types::TrimmedText, max_size?: TITLE_LIMIT)
        required(:type).filled(:string, included_in?: Blog::Types::ArtifactType.values)
        required(:tags).value(Blog::Types::TagList)
        required(:body).filled(Blog::Types::TrimmedText, max_size?: BODY_LIMIT)
      end

      rule(:title).validate(:without_controls, :visible)

      rule(:tags).validate(:tag_slugs)

      rule(:body).validate(:without_controls, :visible)
    end
  end
end
