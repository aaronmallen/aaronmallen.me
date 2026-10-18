# frozen_string_literal: true

module Agents
  class Slice < Hanami::Slice
    import keys: %w[repos.project_queries], from: :projects

    export %w[
      operations.add_memory_fact operations.create_memory_file operations.delete_memory_file
      operations.edit_memory_fact operations.load_memory operations.remove_memory_fact
      operations.revert_memory_event repos.memory_file_queries
    ]
  end
end
