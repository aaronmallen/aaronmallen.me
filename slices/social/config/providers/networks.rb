# frozen_string_literal: true

Social::Slice.register_provider :networks do
  start do
    bluesky = Social::Providers::NetworksProvider.bluesky(target["settings"], target["http"])
    mastodon = Social::Providers::NetworksProvider.mastodon(target["settings"], target["http"])

    register "networks.all", Social::Providers::NetworksProvider.all(bluesky, mastodon)
  end
end
