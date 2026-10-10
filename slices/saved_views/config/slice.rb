# frozen_string_literal: true

module SavedViews
  class Slice < Hanami::Slice
    export %w[
      operations.change_saved_view operations.create_saved_view operations.delete_saved_view
      operations.rename_saved_view repos.saved_view_queries
    ]
  end
end
