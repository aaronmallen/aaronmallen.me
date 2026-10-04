# frozen_string_literal: true

module Blog
  module SecretCheck
    COMMITTED_ENVIRONMENTS = %i[development test].freeze
    SETTINGS_DIRECTORY = File.expand_path("../../config/settings", __dir__)

    def self.call(secrets) = repeated(secrets).merge(committed(secrets))

    def self.committed(secrets)
      return {} if Hanami.env?(*COMMITTED_ENVIRONMENTS)

      values = committed_values(secrets.keys)
      secrets.filter_map do |name, value|
        [name, "must not use a value committed for development or test"] if values.include?(value)
      end.to_h
    end
    private_class_method :committed

    def self.committed_values(names)
      COMMITTED_ENVIRONMENTS.flat_map do |environment|
        path = File.join(SETTINGS_DIRECTORY, "#{environment}.yml")
        next [] unless File.exist?(path)

        store = Hanami::Settings::FileStore.new(path)
        names.filter_map { store.fetch(it, nil) }
      end
    end
    private_class_method :committed_values

    def self.repeated(secrets)
      secrets.to_a.combination(2).filter_map do |(name, value), (other, other_value)|
        [name, "must not repeat #{other}"] if value == other_value
      end.to_h
    end
    private_class_method :repeated
  end
end
