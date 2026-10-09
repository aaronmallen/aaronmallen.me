# frozen_string_literal: true

Admin::Slice.register_provider :mastodon do
  start do
    register "mastodon.auth", Admin::Auth::Mastodon.new(website: target["settings"].site_url)
  end
end
