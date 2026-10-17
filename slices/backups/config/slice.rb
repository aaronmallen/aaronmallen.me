# frozen_string_literal: true

module Backups
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/backups"), namespace: Backups)

    config.shared_app_component_keys += %w[backup_store.client]

    export []
  end
end
