# frozen_string_literal: true

module Agents
  class Slice < Hanami::Slice
    import keys: %w[operations.save_project repos.project_queries], from: :projects
    import keys: %w[operations.add_repo_rule], from: :tasks

    export %w[
      operations.add_memory_fact operations.change_memory_scope operations.create_artifact operations.create_memory_file
      operations.delete_artifact operations.delete_memory_file operations.describe_memory_file
      operations.edit_memory_fact operations.end_session operations.find_project operations.load_memory
      operations.record_loads operations.record_read operations.record_search operations.remove_memory_fact
      operations.restore_artifact_version operations.revert_memory_event operations.search_memory
      operations.start_session operations.update_artifact repos.agent_session_queries repos.artifact_queries
      repos.memory_file_queries
    ]
  end
end
