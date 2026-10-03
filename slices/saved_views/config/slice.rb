# frozen_string_literal: true

module SavedViews
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/saved_views"), namespace: SavedViews)

    export %w[
      operations.change_saved_view operations.create_saved_view operations.delete_saved_view
      operations.rename_saved_view queries.all queries.by_id
    ]
  end
end
