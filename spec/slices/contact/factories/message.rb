# frozen_string_literal: true

require "digest"

Spec::DB::Factories.define(:message) do |f|
  f.sequence(:reply_to) { |n| "sender-#{n}@example.com" }
  f.subject { Faker::Book.title }
  f.body { Faker::Lorem.paragraph }
  f.status "unread"
  f.sequence(:visitor_hash) { |n| Digest::SHA256.hexdigest("sender-#{n}") }
  f.received_at { Time.now }
  f.marked_spam_at { |status| Time.now if status == "spam" }

  f.trait :read do |t|
    t.status "read"
  end

  f.trait :spam do |t|
    t.status "spam"
    t.marked_spam_at { Time.now }
  end
end
