# frozen_string_literal: true

Admin::Slice.register_provider :live, namespace: true do
  start do
    url = Blog::Providers::DBProvider.database_url(target.app["settings"].database)

    register :hub, Admin::Live::Hub.new(url:, reporter: target.app["honeybadger.agent"])
  end

  stop do
    target["live.hub"].stop
  end
end
