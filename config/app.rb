# frozen_string_literal: true

require "hanami"
require "hanami-settings-stores"
require "honeybadger/rack/error_notifier"
require "json"
require "phlex-hanami"
require "rack/static"
require "blog/extensions/dry/logger/filter/extension"
require "blog/extensions/hanami/cli/db/postgres/extension" if defined?(Hanami::CLI)
require "blog/extensions/hanami/middleware/assets/extension"
require "blog/extensions/hanami/providers/routes/extension"
require "blog/extensions/hanami/router/extension"
require "blog/extensions/hanami/router/node/extension"
require "blog/extensions/hanami/router/trie/extension"
require "blog/extensions/rom/sql/postgres/type_builder/extension"
require "blog/params_guard"
require "blog/request_connection"
require "blog/request_timer"
require "blog/theme_script"
require "blog/providers/honeybadger_provider"
require "blog/version"
require "bluesky"
require "github"
require "google"
require "issues"
require "linear"
require "linkedin"
require "markdown"
require "mastodon"
require "object_store"
require "page_fetcher"

module Blog
  class App < Hanami::App
    autoloader.push_dir(root.join("lib/bluesky"), namespace: Bluesky)
    autoloader.push_dir(root.join("lib/github"), namespace: GitHub)
    autoloader.push_dir(root.join("lib/google"), namespace: Google)
    autoloader.push_dir(root.join("lib/issues"), namespace: Issues)
    autoloader.push_dir(root.join("lib/linear"), namespace: Linear)
    autoloader.push_dir(root.join("lib/linkedin"), namespace: LinkedIn)
    autoloader.push_dir(root.join("lib/markdown"), namespace: Markdown)
    autoloader.push_dir(root.join("lib/mastodon"), namespace: Mastodon)
    autoloader.push_dir(root.join("lib/object_store"), namespace: ObjectStore)
    autoloader.push_dir(root.join("lib/page_fetcher"), namespace: PageFetcher)

    config.inflections do |inflections|
      inflections.acronym "CLI", "GitHub", "LinkedIn", "MCP", "OAuth", "PKCE", "UI", "URI"
    end

    config.actions.content_security_policy[:manifest_src] = "'self'"
    config.actions.content_security_policy[:script_src] += " #{Blog::ThemeScript::SOURCE_HASH}"
    config.actions.method_override = false
    config.actions.view_name_inference_base = "ui.views"

    config.logger.filters |= %w[\w*_key \w*_secret \w*_token code_challenge code_verifier ip]
    config.logger.filters |= Providers::HoneybadgerProvider::FILTER_KEYS | Providers::HoneybadgerProvider::WHOLE_KEYS

    config.no_auto_register_paths += %w[helpers]
    config.shared_app_component_keys += %w[
      contracts.contributor_terms_contract contracts.review_range_contract contracts.search_query_contract
      github.client google.client linear.client media_store.client networks.all operations.check_link
      operations.read_visitor_address
    ]

    config.middleware.use RequestTimer, ->(**row) { Performance::Slice["operations.record_timing"].call(:request, **row) }
    config.middleware.use Honeybadger::Rack::ErrorNotifier
    config.middleware.use ParamsGuard, ->(request) { Admin::Slice["auth.session_reader"].call(request) }
    config.middleware.use Rack::Static, root: "public", urls: ["/favicon.ico"]
    config.middleware.use RequestConnection, -> { Hanami.app["db.rom"].gateways[:default].connection }

    config.settings_store = Hanami::Settings::CompositeStore.new(
      Hanami::Settings::FileStore.new(config.root.join("config/settings/#{Hanami.env}.yml")),
      Hanami::Settings::FileStore.new(config.root.join("config/settings/default.yml")),
      Hanami::Settings::EnvStore.new,
    )

    config.base_url = settings.site[:url]
  end
end
