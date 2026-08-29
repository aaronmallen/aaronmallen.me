# frozen_string_literal: true

Spec::DB::Factories.define(:social_post_delivery) do |f|
  f.association(:social_post)
  f.network "mastodon"

  f.trait :bluesky do |t|
    t.network "bluesky"
  end

  f.trait :mastodon do |t|
    t.network "mastodon"
  end
end
