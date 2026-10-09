# frozen_string_literal: true

module Services
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/services"), namespace: Services)

    export %w[
      operations.add_connection operations.remove_connection operations.save_app repos.app_queries
      repos.connection_queries repos.definition_queries
    ]
  end
end
