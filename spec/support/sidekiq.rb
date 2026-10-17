# frozen_string_literal: true

require "erb"
require "sidekiq"
require "yaml"

Sidekiq.testing!(:fake)
Hanami.app.start(:sidekiq)
Sidekiq.default_configuration.logger.level = Logger::WARN

module Spec
  class FakeJobSet
    include Enumerable

    attr_reader :name

    def initialize(name)
      @entries = []
      @name = name
    end

    def add(at, item) = @entries << Sidekiq::SortedEntry.new(self, at.to_f, Sidekiq.dump_json(item))

    def delete_by_value(_name, value) = @entries.delete_if { it.value == value }

    def each(&) = @entries.sort_by { -it.score }.each(&)

    def find_job(jid) = find { it.jid == jid }

    def remove_job(entry)
      delete_by_value(name, entry.value)
      yield entry.value
    end

    def size = @entries.size
  end

  module SyncStates
    def sync_state_mutations = Record::Slice["repos.sync_state_mutations"]

    def sync_state_queries = Record::Slice["repos.sync_state_queries"]
  end

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
  config.include Spec::SyncStates
end
