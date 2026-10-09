# frozen_string_literal: true

Spec::DB::Factories.define(:pull_request) do |f|
  f.repo "aaronmallen/aaronmallen.me"
  f.sequence(:number) { it }
  f.title { Faker::Lorem.sentence }
  f.body { Faker::Lorem.paragraph }
  f.url { |repo, number| "https://github.com/#{repo}/pull/#{number}" }
  f.ready_at { Time.now }
end
