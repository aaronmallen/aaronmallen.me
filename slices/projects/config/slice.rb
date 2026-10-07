# frozen_string_literal: true

module Projects
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/projects"), namespace: Projects)

    import keys: %w[github.client operations.record_projects_sync_outcome], from: :record

    export %w[
      operations.add_work_entry operations.archive_project operations.delete_work_entry
      operations.restore_project operations.save_project repos.project_queries repos.work_entry_queries
    ]
  end
end
