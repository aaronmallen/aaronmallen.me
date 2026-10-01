# frozen_string_literal: true

Spec::DB::Factories.define(:webmention) do |f|
  f.post_id { Spec::DB::Factories.create(:post).id }
  f.sequence(:source_url) { |n| "https://source-#{n}.example/note" }
  f.author_name { Faker::Name.name }
  f.sequence(:author_url) { |n| "https://author-#{n}.example/about" }
  f.type "mention"
  f.status "pending"
  f.excerpt { Faker::Lorem.sentence }
  f.received_at { Time.now }

  f.trait :approved do |t|
    t.status "approved"
  end

  f.trait :spam do |t|
    t.status "spam"
  end

  f.trait :ignored do |t|
    t.status "ignored"
  end

  f.trait :like do |t|
    t.type "like"
    t.excerpt nil
  end

  f.trait :mention do |t|
    t.type "mention"
  end

  f.trait :reply do |t|
    t.type "reply"
  end

  f.trait :repost do |t|
    t.type "repost"
    t.excerpt nil
  end
end
