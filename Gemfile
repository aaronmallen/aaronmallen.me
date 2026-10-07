# frozen_string_literal: true

source "https://gem.coop"

source "https://gem.coop/@aaron" do
  gem "hanami-settings-stores", "~> 0.1"
  gem "phlex-hanami", "~> 0.2"
end

source "https://gem.coop/@dry" do
  gem "dry-operation", ">= 1.0.1"
  gem "dry-types", "~> 1"
  gem "dry-validation", "~> 1"
end

source "https://gem.coop/@hanami" do
  gem "hanami", "~> 3"
  gem "hanami-action", "~> 3"
  gem "hanami-assets", "~> 3"
  gem "hanami-db", "~> 3"
  gem "hanami-router", "~> 3"
end

gem "alba", "~> 3"
gem "aws-sdk-s3", "~> 1"
gem "builder", "~> 3"
gem "commonmarker", "~> 2"
gem "faraday", "~> 2"
gem "faraday-follow_redirects", "~> 0.5"
gem "honeybadger", "~> 6"
gem "i18n", "~> 1"
gem "json_schemer", "~> 2"
gem "maxmind-db", "~> 1"
gem "mcp", "~> 1.6"
gem "nokogiri", "~> 1"
gem "oauth2", "~> 2"
gem "pg"
gem "puma", ">= 7.1"
gem "ruby-vips", "~> 2"
gem "sanitize", "~> 7"
gem "sidekiq", "~> 8"
gem "sidekiq-scheduler", "~> 6"
gem "tzinfo", "~> 2"
gem "tzinfo-data"

group :cli, :development do
  gem "hanami-reloader", "~> 3", source: "https://gem.coop/@hanami"
end

group :cli, :development, :test do
  gem "hanami-rspec", "~> 3", source: "https://gem.coop/@hanami"
end

group :development do
  gem "hanami-webconsole", "~> 3", source: "https://gem.coop/@hanami"
end

group :lint do
  gem "rubocop"
  gem "rubocop-capybara"
  gem "rubocop-i18n"
  gem "rubocop-ordered_methods"
  gem "rubocop-performance"
  gem "rubocop-rspec"
end

group :test do
  gem "axe-core-api", "~> 4.13"
  gem "capybara"
  gem "cuprite"
  gem "database_cleaner-sequel"
  gem "faker"
  gem "rack-test"
  gem "rom-factory"
  gem "rspec-collection_matchers"
  gem "simplecov"
  gem "webmock"
end
