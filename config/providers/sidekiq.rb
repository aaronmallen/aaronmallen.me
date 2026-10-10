# frozen_string_literal: true

Hanami.app.register_provider :sidekiq do
  prepare do
    require "sidekiq"
    require "sidekiq/api"
    require "sidekiq-scheduler"
  end

  start do
    redis = target["settings"].redis.compact

    Sidekiq.configure_client { it.redis = redis }
    Sidekiq.configure_server { it.redis = redis }

    register("sidekiq.dead_set") { -> { Sidekiq::DeadSet.new } }
  end
end
