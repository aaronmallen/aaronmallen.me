# frozen_string_literal: true

Spec::DB::Factories.define(:person) do |f|
  f.sequence(:key) { |n| "person-#{n}" }
  f.name { Faker::Name.name }
  f.sequence(:mastodon_handle) { |n| "@person#{n}@ruby.social" }
  f.bluesky_handle nil
  f.bluesky_did nil

  f.trait :bluesky do |t|
    t.sequence(:bluesky_handle) { |n| "person-#{n}.bsky.social" }
    t.sequence(:bluesky_did) { |n| "did:plc:person#{n}" }
  end
end
