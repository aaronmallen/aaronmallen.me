# frozen_string_literal: true

module Projects
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/projects"), namespace: Projects)

    import keys: %w[github.client operations.record_projects_sync_outcome], from: :record

    export %w[
      operations.add_work_entry operations.archive_project operations.delete_work_entry
      operations.restore_project operations.save_project queries.archived queries.by_id queries.by_tag
      queries.linkable_projects queries.linkable_work_entries queries.live
      queries.public_by_tag queries.public_grid queries.work_entries queries.work_entries_between
      queries.work_entry_by_id
    ]
  end
end
