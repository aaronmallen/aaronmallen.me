# frozen_string_literal: true

Spec::DB::Factories.define(:artifact) do |f|
  f.title { Faker::Lorem.sentence }
  f.type "plan"
end
