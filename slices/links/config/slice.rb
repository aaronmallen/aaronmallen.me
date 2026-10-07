# frozen_string_literal: true

module Links
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/links"), namespace: Links)

    import keys: %w[queries.linkable_decisions], from: :decisions
    import keys: %w[queries.linkable_posts], from: :posts
    import keys: %w[queries.linkable_projects queries.linkable_work_entries], from: :projects
    import keys: %w[queries.linkable_commits queries.linkable_journal_entries], from: :record
    import keys: %w[queries.linkable_social_posts], from: :social
    import keys: %w[queries.linkable_tasks], from: :tasks

    export %w[operations.link_records operations.unlink_records queries.find_records queries.record_links]
  end
end
