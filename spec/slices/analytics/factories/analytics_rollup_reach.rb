# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_rollup_reach, relation: :analytics_rollup_reach) do |f|
  f.month { Date.new(Blog::TimeZone.today.year, Blog::TimeZone.today.month, 1) }
  f.path nil
  f.reach 10
end
