# frozen_string_literal: true

module Tags
  class Slice < Hanami::Slice
    import keys: %w[repos.agent_session_queries repos.artifact_queries repos.memory_file_queries], from: :agents

    import keys: %w[repos.decision_queries], from: :decisions

    import keys: %w[repos.thread_queries], from: :mail

    import keys: %w[repos.note_queries], from: :notes

    import keys: %w[repos.post_tag_queries], from: :posts

    import keys: %w[repos.project_queries], from: :projects

    import keys: %w[repos.journal_entry_queries], from: :record

    import keys: %w[repos.task_queries], from: :tasks

    export %w[operations.remove_tag operations.save_tag repos.tag_queries]
  end
end
