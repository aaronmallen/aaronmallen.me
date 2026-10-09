# frozen_string_literal: true

Spec::DB::Factories.define(:pull_request) do |f|
  f.sequence(:number) { |n| n }
  f.repo "aaronmallen/aaronmallen.me"
  f.title { Faker::Lorem.sentence }
  f.body ""
  f.url { |repo, number| "https://github.com/#{repo}/pull/#{number}" }
  f.ready_at { Time.now }
end
