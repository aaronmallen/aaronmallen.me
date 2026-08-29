# frozen_string_literal: true

require "hanami"
require "hanami-settings-stores"
require "honeybadger/rack/error_notifier"
require "json"
require "phlex-hanami"
require "blog/extensions/dry/logger/filter/extension"
require "blog/extensions/hanami/cli/db/postgres/extension" if defined?(Hanami::CLI)
require "blog/extensions/hanami/providers/routes/extension"
require "blog/extensions/hanami/router/node/extension"
require "blog/extensions/hanami/router/trie/extension"
require "blog/params_guard"
require "blog/providers/honeybadger_provider"

module Blog
  class App < Hanami::App
    config.inflections do |inflections|
      inflections.acronym "CLI", "GitHub", "MCP", "OAuth", "PKCE", "UI", "URI"
    end

    config.actions.view_name_inference_base = "ui.views"

    config.logger.filters |= %w[_csrf_token client_secret code_challenge code_verifier refresh_token]
    config.logger.filters |= Providers::HoneybadgerProvider::FILTER_KEYS

    config.middleware.use Honeybadger::Rack::ErrorNotifier
    config.middleware.use ParamsGuard

    config.settings_store = Hanami::Settings::CompositeStore.new(
      Hanami::Settings::FileStore.new(config.root.join("config/settings/#{Hanami.env}.yml")),
      Hanami::Settings::FileStore.new(config.root.join("config/settings/default.yml")),
      Hanami::Settings::EnvStore.new,
    )

    config.base_url = settings.site[:url]
  end
end
