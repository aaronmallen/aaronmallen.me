# frozen_string_literal: true

require "erb"
require "yaml"

module Blog
  module SidekiqConfig
    PATH = File.expand_path("../../config/sidekiq.yml.erb", __dir__)

    def self.load
      template = ERB.new(File.read(PATH), trim_mode: "-")
      template.filename = PATH

      YAML.safe_load(template.result, permitted_classes: [Symbol], aliases: true).transform_keys(&:to_sym)
    end
  end
end
