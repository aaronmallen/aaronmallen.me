# frozen_string_literal: true

Spec::DB::Factories.define(:health_day) do |f|
  f.day { Blog::TimeZone.today }
end
