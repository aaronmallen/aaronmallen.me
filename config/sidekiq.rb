# frozen_string_literal: true

require "sidekiq"
require "sidekiq-scheduler"
require "hanami/boot"

Sidekiq.configure_server do |config|
  record = ->(**row) { Performance::Slice["operations.record_timing"].call(:job, **row) }

  config.server_middleware { it.add Blog::JobTimer, record }
end
