# frozen_string_literal: true

Social::Slice.register_provider :webmentions do
  start do
    register "webmentions.client", Social::Providers::WebmentionsProvider.build(target["http"])
    register "webmentions.link_checker", Social::Providers::WebmentionsProvider.build(
      target["http"], agent: Social::Providers::WebmentionsProvider::LINK_CHECK_AGENT,
    )
  end
end
