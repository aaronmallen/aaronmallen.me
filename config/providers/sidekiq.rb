# frozen_string_literal: true

Hanami.app.register_provider :sidekiq do
  prepare do
    require "sidekiq"
    require "sidekiq-scheduler"
  end

  start do
    redis = target["settings"].redis.compact

    Sidekiq.configure_client { it.redis = redis }
    Sidekiq.configure_server { it.redis = redis }
  end
end
