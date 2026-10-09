# frozen_string_literal: true

module Services
  Definition = Data.define(
    :id, :name, :icon, :group, :auth, :account, :dashboard, :env, :fields, :jobs, :multiple, :powers, :scopes,
  ) do
    def self.load(path)
      new(id: File.basename(path, ".yml"), **YAML.load_file(path, symbolize_names: true))
    end

    def initialize(
      id:, name:, icon:, group:, auth:,
      account: nil, dashboard: nil, env: {}, fields: [], jobs: [], multiple: false, powers: [], scopes: []
    )
      super
    end

    def connectable? = %w[credentials oauth].include?(auth)

    def oauth? = auth == "oauth"
  end
end
