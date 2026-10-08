# frozen_string_literal: true

ENV["HANAMI_ENV"] ||= "production"

require "hanami/setup"
require "blog/params_guard"

rackup File.expand_path("../.config/config.ru", File.dirname(__FILE__))
port ENV.fetch("HANAMI_PORT", 2300), ENV.fetch("HANAMI_HOST", "127.0.0.1")
environment ENV.fetch("HANAMI_ENV")
max_threads_count = Hanami.app.settings.web_threads
min_threads_count = ENV.fetch("HANAMI_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count
puma_concurrency = Integer(ENV.fetch("HANAMI_WEB_CONCURRENCY", 0))
puma_cluster_mode = puma_concurrency > 1
workers puma_concurrency
http_content_length_limit Blog::ParamsGuard::ENCODED_UPLOAD_LIMIT

if puma_cluster_mode
  before_fork do
    Hanami.shutdown
  end
end
