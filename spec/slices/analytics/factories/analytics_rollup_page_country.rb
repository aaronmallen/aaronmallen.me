# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_rollup_page_country) do |f|
  f.day { Spec::DB::Factories.create(:analytics_rollup).day }
  f.path "/writing/hello"
  f.country_code "US"
  f.views 12
  f.visitors 8

  f.trait :unknown do |t|
    t.country_code nil
  end
end
