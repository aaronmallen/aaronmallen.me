# frozen_string_literal: true

Spec::DB::Factories.define(:analytics_rollup_device) do |f|
  f.day { Spec::DB::Factories.create(:analytics_rollup).day }
  f.path nil
  f.device_class "desktop"
  f.views 12
  f.visitors 8
end
