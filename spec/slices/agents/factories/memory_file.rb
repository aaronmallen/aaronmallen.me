# frozen_string_literal: true

Spec::DB::Factories.define(:memory_file) do |f|
  f.sequence(:path) { |n| "notes-#{n}.md" }
  f.scope "global"
  f.description "notes for agents"
end
