# frozen_string_literal: true

MCP::Slice.configure_provider :db do
  Blog::Providers::DBProvider.configure(config, target.app["settings"])
end
