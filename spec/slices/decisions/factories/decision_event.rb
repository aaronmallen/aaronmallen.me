# frozen_string_literal: true

Spec::DB::Factories.define(:decision_event) do |f|
  f.association(:decision)
  f.kind "opened"
  f.created_at { Time.now }
end
