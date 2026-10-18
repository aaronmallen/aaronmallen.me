# frozen_string_literal: true

module Agents
  module Contracts
    class SessionContract < Blog::Contract
      BRANCH_LIMIT = 255
      CLIENT_LIMIT = 200
      TITLE_LIMIT = 200

      params do
        required(:title).filled(Blog::Types::TrimmedText, max_size?: TITLE_LIMIT)
        required(:agent).filled(Blog::Types::Normalized::ContributorSlug)
        required(:model).filled(Blog::Types::Normalized::ContributorSlug)
        optional(:client).maybe(Blog::Types::OptionalText, max_size?: CLIENT_LIMIT)
        optional(:repo).maybe(Blog::Types::Nullable::Repo)
        optional(:branch).maybe(Blog::Types::OptionalText, max_size?: BRANCH_LIMIT)
        optional(:task_ids).value(Blog::Types::IdList, max_size?: MAX_IDS)
      end

      rule(:title).validate(:without_controls, :visible)

      rule(:client).validate(:without_controls)

      rule(:branch).validate(:without_controls)
    end
  end
end
