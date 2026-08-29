# frozen_string_literal: true

require "digest"

Spec::DB::Factories.define(:analytics_event) do |f|
  f.sequence(:path) { |n| "/writing/post-#{n}" }
  f.title { Faker::Book.title }
  f.sequence(:visitor_hash) { |n| Digest::SHA256.hexdigest("visitor-#{n}") }
  f.sequence(:address_hash) { |n| Digest::SHA256.hexdigest("address-#{n}") }
  f.sequence(:view_token) { |n| Digest::SHA256.hexdigest("view-#{n}")[0, 32] }
  f.referrer_host "news.example"
  f.country_code "US"
  f.read_seconds 42
  f.occurred_at { Time.now }

  f.trait :direct do |t|
    t.referrer_host nil
  end

  f.trait :unknown_country do |t|
    t.country_code nil
  end
end
