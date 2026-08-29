# frozen_string_literal: true

Spec::DB::Factories.define(:commit) do |f|
  f.sequence(:sha) { |n| format("%040d", n) }
  f.repo "aaronmallen/aaronmallen.me"
  f.branch "main"
  f.message { Faker::Lorem.sentence }
  f.commit_date { Blog::TimeZone.today }
  f.commit_time "09:00"
  f.additions { Faker::Number.between(from: 1, to: 200) }
  f.deletions { Faker::Number.between(from: 0, to: 200) }
end
