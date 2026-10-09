# frozen_string_literal: true

Social::Slice.register_provider :networks do
  start do
    scan_links = target["operations.scan_links"]
    bluesky = Social::Providers::NetworksProvider.bluesky(
      target["services.repos.connection_queries"], target["http"],
      scan_links:, scan_tags: target["operations.scan_tags"],
    )
    mastodon = Social::Providers::NetworksProvider.mastodon(target["settings"], target["http"], scan_links:)

    register "networks.all", Social::Providers::NetworksProvider.all(bluesky, mastodon)
  end
end
