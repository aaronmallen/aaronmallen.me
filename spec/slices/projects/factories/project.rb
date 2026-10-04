# frozen_string_literal: true

Spec::DB::Factories.define(:project) do |f|
  f.sequence(:name) { |n| "project-#{n}" }
  f.tagline { Faker::Lorem.sentence }
  f.sequence(:repo) { |n| "aaronmallen/project-#{n}" }
  f.sequence(:url) { |n| "https://github.com/aaronmallen/project-#{n}" }
  f.stars { Faker::Number.between(from: 0, to: 500) }
  f.release "v1.0.0"
  f.status "active"
  f.featured false
  f.sequence(:position) { |n| n }
  f.started_on { Blog::TimeZone.today - 365 }
  f.archived_on nil

  f.trait :archived do |t|
    t.status "archived"
    t.archived_on { Blog::TimeZone.today }
  end

  f.trait :featured do |t|
    t.featured true
  end

  f.trait :paused do |t|
    t.status "paused"
  end

  f.trait :wip do |t|
    t.status "wip"
  end
end
