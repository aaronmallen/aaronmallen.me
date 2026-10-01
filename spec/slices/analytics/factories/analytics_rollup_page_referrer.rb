# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_rollup_page_referrer) do |f|
  f.day { Spec::DB::Factories.create(:analytics_rollup).day }
  f.path "/writing/hello"
  f.sequence(:host) { |n| "referrer-#{n}.example" }
  f.views 12
  f.visitors 8

  f.trait :direct do |t|
    t.host nil
  end
end
