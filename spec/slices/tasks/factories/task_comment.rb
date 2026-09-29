# frozen_string_literal: true

Spec::DB::Factories.define(:task_comment) do |f|
  f.association(:task)
  f.body { Faker::Lorem.sentence }

  f.trait :synced do |t|
    t.provider "github"
    t.sequence(:remote_id) { |n| "IC_#{n}" }
    t.author "octocat"
    t.url { |remote_id| "https://github.com/aaronmallen/aaronmallen.me/issues/1#issuecomment-#{remote_id.delete_prefix('IC_')}" }
  end
end
