# frozen_string_literal: true

module Tags
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/tags"), namespace: Tags)

    import keys: %w[repos.decision_queries], from: :decisions

    import keys: %w[repos.post_queries], from: :posts

    import keys: %w[repos.project_queries], from: :projects

    import keys: %w[repos.journal_entry_queries], from: :record

    import keys: %w[queries.tasks_by_tag], from: :tasks

    export %w[
      operations.remove_tag operations.save_tag queries.all queries.by_id queries.matching queries.matching_count
      queries.summary queries.usage
    ]
  end
end
