# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_rollup_path) do |f|
  f.day { Spec::DB::Factories.create(:analytics_rollup).day }
  f.sequence(:path) { |n| "/writing/post-#{n}" }
  f.title { Faker::Book.title }
  f.views 30
  f.visitors 20
  f.read_seconds 900
  f.bounces 5
end
