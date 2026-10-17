# frozen_string_literal: true

module Health
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/health"), namespace: Health)

    config.shared_app_component_keys += %w[honeybadger.agent]

    import keys: %w[repos.sync_state_queries], from: :record

    export %w[operations.queue_backfill repos.health_queries]
  end
end
