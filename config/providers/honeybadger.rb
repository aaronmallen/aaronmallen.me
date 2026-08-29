# frozen_string_literal: true

Hanami.app.register_provider :honeybadger, namespace: true do
  start do
    register :agent, Blog::Providers::HoneybadgerProvider.agent(target["settings"], Hanami.env)
  end
end
