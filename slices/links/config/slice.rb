# frozen_string_literal: true

module Links
  class Slice < Hanami::Slice
    import keys: %w[repos.artifact_queries repos.memory_file_queries], from: :agents
    import keys: %w[repos.decision_queries], from: :decisions
    import keys: %w[repos.thread_queries], from: :mail
    import keys: %w[repos.note_queries], from: :notes
    import keys: %w[repos.post_queries], from: :posts
    import keys: %w[repos.project_queries repos.work_entry_queries], from: :projects
    import keys: %w[repos.commit_queries repos.journal_entry_queries repos.pull_request_queries], from: :record
    import keys: %w[repos.social_post_queries], from: :social
    import keys: %w[operations.set_task_project repos.task_label_queries], from: :tasks

    export %w[operations.link_records operations.unlink_records repos.record_link_queries]
  end
end
