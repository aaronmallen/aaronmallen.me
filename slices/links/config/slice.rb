# frozen_string_literal: true

module Links
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/links"), namespace: Links)

    import keys: %w[repos.decision_queries], from: :decisions
    import keys: %w[repos.post_queries], from: :posts
    import keys: %w[repos.project_queries repos.work_entry_queries], from: :projects
    import keys: %w[repos.commit_queries repos.journal_entry_queries], from: :record
    import keys: %w[repos.social_post_queries], from: :social
    import keys: %w[repos.task_queries], from: :tasks

    export %w[operations.link_records operations.unlink_records repos.record_link_queries]
  end
end
