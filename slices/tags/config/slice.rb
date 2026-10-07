# frozen_string_literal: true

module Tags
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/tags"), namespace: Tags)

    import keys: %w[repos.decision_queries], from: :decisions

    import keys: %w[repos.post_queries], from: :posts

    import keys: %w[repos.project_queries], from: :projects

    import keys: %w[repos.journal_entry_queries], from: :record

    import keys: %w[repos.task_queries], from: :tasks

    export %w[operations.remove_tag operations.save_tag repos.tag_queries]
  end
end
