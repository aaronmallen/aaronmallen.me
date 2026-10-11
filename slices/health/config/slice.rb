# frozen_string_literal: true

module Health
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/health"), namespace: Health)

    import keys: %w[operations.change_connection repos.connection_queries], from: :services

    export %w[google.client]
  end
end
