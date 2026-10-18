# frozen_string_literal: true

module Agents
  module Contracts
    class MemoryFileContract < AuthorContract
      EXTRA = "extra"
      PATH = Blog::Types::String.constructor do |value|
        path = Blog::Types::TrimmedText[value.to_s]
        path.end_with?(".md") ? path : "#{path}.md"
      end
      PATH_FORMAT = %r{\A[\w./-]+\.md\z}
      TARGETS = { "repo" => :repo, "project" => :project_id, "task" => :task_id }.freeze

      params(AUTHOR) do
        required(:path).filled(PATH, format?: PATH_FORMAT)
        required(:scope).filled(:string, included_in?: Blog::Types::MemoryScope.values)
        optional(:repo).maybe(Blog::Types::Nullable::Repo)
        optional(:project_id).maybe(:integer)
        optional(:task_id).maybe(:integer)
      end

      rule(:scope) do
        TARGETS.each do |scope, field|
          wanted = value == scope
          key(field).failure(MISSING) if wanted && values[field].nil?
          key(field).failure(EXTRA) if !wanted && !values[field].nil?
        end
      end
    end
  end
end
