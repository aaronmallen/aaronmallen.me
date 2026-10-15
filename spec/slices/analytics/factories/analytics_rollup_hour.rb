# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_rollup_hour) do |f|
  f.day { Spec::DB::Factories.create(:analytics_rollup).day }
  f.hour 9
  f.visitors 3
end
