# frozen_string_literal: true

require "hanami"
require "hanami-settings-stores"
require "honeybadger/rack/error_notifier"
require "json"
require "phlex-hanami"
require "rack/static"
require "blog/extensions/dry/logger/filter/extension"
require "blog/extensions/hanami/cli/db/postgres/extension" if defined?(Hanami::CLI)
require "blog/extensions/hanami/providers/routes/extension"
require "blog/extensions/hanami/router/node/extension"
require "blog/extensions/hanami/router/trie/extension"
require "blog/extensions/rom/sql/postgres/type_builder/extension"
require "blog/params_guard"
require "blog/providers/honeybadger_provider"
require "blog/version"

module Blog
  class App < Hanami::App
    config.inflections do |inflections|
      inflections.acronym "CLI", "GitHub", "MCP", "OAuth", "PKCE", "UI", "URI"
    end

    config.actions.content_security_policy[:manifest_src] = "'self'"
    config.actions.method_override = false
    config.actions.view_name_inference_base = "ui.views"

    config.logger.filters |= %w[\w*_key \w*_secret \w*_token code_challenge code_verifier ip]
    config.logger.filters |= Providers::HoneybadgerProvider::FILTER_KEYS

    config.no_auto_register_paths += %w[helpers]

    config.middleware.use Honeybadger::Rack::ErrorNotifier
    config.middleware.use ParamsGuard
    config.middleware.use Rack::Static, root: "public", urls: ["/favicon.ico"]

    config.settings_store = Hanami::Settings::CompositeStore.new(
      Hanami::Settings::FileStore.new(config.root.join("config/settings/#{Hanami.env}.yml")),
      Hanami::Settings::FileStore.new(config.root.join("config/settings/default.yml")),
      Hanami::Settings::EnvStore.new,
    )

    config.base_url = settings.site[:url]
  end
end
