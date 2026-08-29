# frozen_string_literal: true

Posts::Slice.configure_provider :db do
  Blog::Providers::DBProvider.configure(config, target.app["settings"])
end
