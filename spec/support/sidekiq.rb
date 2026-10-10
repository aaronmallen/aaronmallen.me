# frozen_string_literal: true

require "erb"
require "sidekiq"
require "yaml"

Sidekiq.testing!(:fake)
Hanami.app.start(:sidekiq)
Sidekiq.default_configuration.logger.level = Logger::WARN

module Spec
  module SidekiqConfig
    def sidekiq_config(environment = :development)
      path = Hanami.app.root.join("config/sidekiq.yml.erb")
      template = ERB.new(File.read(path), trim_mode: "-")
      template.filename = path.to_s
      config = YAML.safe_load(template.result, permitted_classes: [Symbol], aliases: true).transform_keys(&:to_sym)

      config.merge(config.delete(environment.to_sym) || {})
    end
  end
end

RSpec.configure do |config|
  config.before { Sidekiq::Job.clear_all }
  config.include Spec::SidekiqConfig
end
