# frozen_string_literal: true

Admin::Slice.configure_provider :db do
  Blog::Providers::DBProvider.configure(config, target.app["settings"])
end
