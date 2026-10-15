# frozen_string_literal: true

require "sidekiq"
require "sidekiq-scheduler"
require "hanami/boot"

RubyVM::YJIT.enable if Hanami.env?(:production) && defined?(RubyVM::YJIT.enable)

Sidekiq.configure_server do |config|
  database = -> { Hanami.app["db.rom"].gateways[:default].connection }
  record = ->(**row) { Performance::Slice["operations.record_timing"].call(:job, **row) }

  config.server_middleware do |chain|
    chain.add Blog::JobConnection, database
    chain.add Blog::JobTimer, record
  end

  config.on(:startup) { Analytics::Slice["operations.queue_country_database"].call }
end
