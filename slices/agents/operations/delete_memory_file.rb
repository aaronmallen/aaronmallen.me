# frozen_string_literal: true

module Agents
  module Operations
    class DeleteMemoryFile < Blog::Operation
      include Deps[memory_file_mutations: "repos.memory_file_mutations"]

      def call(id) = step found(memory_file_mutations.delete(id))
    end
  end
end
