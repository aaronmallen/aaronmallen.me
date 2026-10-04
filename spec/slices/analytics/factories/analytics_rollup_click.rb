# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_rollup_click) do |f|
  f.day { Spec::DB::Factories.create(:analytics_rollup).day }
  f.sequence(:path) { |n| "/writing/post-#{n}" }
  f.link_host "docs.example"
  f.sequence(:link_path) { |n| "/guide-#{n}" }
  f.clicks 1
end
