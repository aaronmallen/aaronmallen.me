# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_rollup_referrer) do |f|
  f.day { Spec::DB::Factories.create(:analytics_rollup).day }
  f.sequence(:host) { |n| "referrer-#{n}.example" }
  f.views 12

  f.trait :direct do |t|
    t.host nil
  end
end
