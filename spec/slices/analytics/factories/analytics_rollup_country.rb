# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_rollup_country) do |f|
  f.day { Spec::DB::Factories.create(:analytics_rollup).day }
  f.country_code "US"
  f.views 12

  f.trait :unknown do |t|
    t.country_code nil
  end
end
