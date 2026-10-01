# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_rollup_source) do |f|
  f.day { Spec::DB::Factories.create(:analytics_rollup).day }
  f.path nil
  f.sequence(:source) { |n| "source-#{n}" }
  f.views 12
  f.visitors 8
end
