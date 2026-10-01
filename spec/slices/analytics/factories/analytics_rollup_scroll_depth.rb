# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_rollup_scroll_depth) do |f|
  f.day { Spec::DB::Factories.create(:analytics_rollup).day }
  f.sequence(:path) { |n| "/writing/post-#{n}" }
  f.scroll_depth 0
  f.views 4
  f.visitors 3
end
