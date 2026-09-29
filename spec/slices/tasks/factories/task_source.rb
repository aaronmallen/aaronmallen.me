# frozen_string_literal: true

Spec::DB::Factories.define(:task_source) do |f|
  f.association(:task)
  f.provider "github"
  f.sequence(:remote_id) { |n| "I_#{n}" }
  f.url { |remote_id| "https://github.com/aaronmallen/aaronmallen.me/issues/#{remote_id.delete_prefix('I_')}" }
end
