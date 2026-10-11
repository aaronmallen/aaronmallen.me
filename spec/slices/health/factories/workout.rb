# frozen_string_literal: true

Spec::DB::Factories.define(:workout) do |f|
  f.sequence(:google_id) { "users/me/dataTypes/exercise/dataPoints/#{it}" }
  f.kind "RUNNING"
  f.started_at { Time.now }
  f.minutes 30
end
