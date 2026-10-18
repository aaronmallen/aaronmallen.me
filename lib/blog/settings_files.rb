# frozen_string_literal: true

require "erb"
require "yaml"

module Blog
  module SettingsFiles
    def self.load(directory, environment)
      default, overrides = %W[default #{environment}].map { read(File.join(directory, "#{it}.yml")) }
      merge(default, overrides).transform_keys(&:to_sym)
    end

    def self.merge(base, override)
      base.merge(override) { |_, old, new| old.is_a?(Hash) && new.is_a?(Hash) ? merge(old, new) : new }
    end
    private_class_method :merge

    def self.read(path) = YAML.safe_load(ERB.new(File.read(path)).result, aliases: true) || {}
    private_class_method :read
  end
end
