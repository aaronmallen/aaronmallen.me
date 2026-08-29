# frozen_string_literal: true

Spec::DB::Factories.define(:social_post) do |f|
  f.targets { %w[mastodon bluesky] }
  f.status "draft"
  f.posted_at nil
  f.association(:parts, count: 1)

  f.trait :draft do |t|
    t.status "draft"
    t.posted_at nil
  end

  f.trait :scheduled do |t|
    t.status "scheduled"
    t.posted_at { Time.now + (24 * 60 * 60) }
  end

  f.trait :posted do |t|
    t.status "posted"
    t.posted_at { Time.now - (24 * 60 * 60) }
  end

  f.trait :thread do |t|
    t.association(:parts, count: 3)
  end
end
