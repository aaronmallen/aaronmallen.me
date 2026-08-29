# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_rollup) do |f|
  f.sequence(:day) { |n| Blog::TimeZone.today - (n - 1) }
  f.views 120
  f.visitors 80
  f.read_seconds 3_600
end
