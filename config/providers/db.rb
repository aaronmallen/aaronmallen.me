# frozen_string_literal: true

require "blog/providers/db_provider"

Hanami.app.configure_provider :db do
  Blog::Providers::DBProvider.configure(config, target.app["settings"])
end
