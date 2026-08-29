# frozen_string_literal: true

Social::Slice.register_provider :webmentions do
  start do
    register "webmentions.client", Social::Providers::WebmentionsProvider.build(target["http"])
  end
end
