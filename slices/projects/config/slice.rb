# frozen_string_literal: true

module Projects
  class Slice < Hanami::Slice
    export %w[
      operations.add_work_entry operations.archive_project operations.delete_work_entry
      operations.restore_project operations.save_project operations.tag_project operations.untag_project
      repos.project_queries repos.work_entry_queries
    ]
  end
end
