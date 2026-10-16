# frozen_string_literal: true

module Tasks
  module Contracts
    class TaskContract < Blog::Contract
      MISSING = "missing"

      include Deps[project_queries: "projects.repos.project_queries"]

      params do
        required(:title).value(Blog::Types::TrimmedText, :filled?)
        required(:list).maybe(Blog::Types::Nullable::TaskFilter)
        required(:note).value(Blog::Types::TrimmedText)
        required(:tags).value(Blog::Types::TagList)
        optional(:contributors).value(:array)
        optional(:project).maybe(Blog::Types::Nullable::ProjectKey)
      end

      rule(:contributors) do
        key.failure(FORMAT) if key? && !value.all? { Blog::Types::Contributor.valid?(it) }
      end

      rule(:project) { key.failure(MISSING) if value && !project_queries.live_id_by_key(value) }

      rule(:title).validate(:without_controls, :visible)
      rule(:note).validate(:without_controls)
      rule(:tags).validate(:tag_slugs)
    end
  end
end
