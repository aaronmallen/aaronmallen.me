# frozen_string_literal: true

Hanami.app.register_provider :http do
  start do
    register "http", Blog::Providers::HTTPProvider.build(target["settings"])
  end
end
