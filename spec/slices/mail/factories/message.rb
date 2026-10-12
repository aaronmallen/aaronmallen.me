# frozen_string_literal: true

require "digest"

Spec::DB::Factories.define(:message, relation: :mail_threads) do |f|
  f.mail_account_id { Mail::Slice["relations.mail_accounts"].contact_form_id }
  f.subject { Faker::Book.title }
  f.status "unread"
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

Spec::DB::Factories.define(:mail_account) do |f|
  f.provider "gmail"
  f.sequence(:name) { |n| "account-#{n}@example.com" }
end

Spec::DB::Factories.define(:mail_message) do |f|
  f.sequence(:reply_to) { |n| "sender-#{n}@example.com" }
  f.subject { Faker::Book.title }
  f.body { Faker::Lorem.paragraph }
  f.sequence(:visitor_hash) { |n| Digest::SHA256.hexdigest("sender-#{n}") }
  f.received_at { Time.now }
end

Spec::DB::Factories.define(:mail_label) do |f|
  f.sequence(:name) { |n| "label-#{n}" }
  f.sequence(:gmail_id) { |n| "Label_#{n}" }
end

Spec::DB::Factories.define(:mail_thread_label) do |f|
  f.mail_thread_id 0
  f.mail_label_id 0
end
