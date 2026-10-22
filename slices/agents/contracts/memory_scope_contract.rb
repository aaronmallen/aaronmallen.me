# frozen_string_literal: true

module Agents
  module Contracts
    class MemoryScopeContract < AuthorContract
      EXTRA = "extra"
      TARGETS = { "project" => :project_id, "task" => :task_id }.freeze

      SCOPE = Dry::Schema.Params do
        required(:scope).filled(:string, included_in?: Blog::Types::MemoryScope.values)
        optional(:project_id).maybe(:integer)
        optional(:task_id).maybe(:integer)
      end

      params(AUTHOR, SCOPE)

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
