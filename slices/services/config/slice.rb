# frozen_string_literal: true

module Services
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/services"), namespace: Services)

    export %w[repos.connection_queries repos.definition_queries]
  end
end
