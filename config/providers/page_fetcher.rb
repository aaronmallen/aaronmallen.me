# frozen_string_literal: true

Hanami.app.register_provider :page_fetcher, namespace: true do
  start do
    register :link_check, PageFetcher::Provider.build(target["http"], agent: "link-check")
    register :link_title, PageFetcher::Provider.build(target["http"], agent: "link-title")
    register :webmention, PageFetcher::Provider.build(target["http"], agent: "webmention")
  end
end
