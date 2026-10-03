# frozen_string_literal: true

Spec::DB::Factories.define(:work_session) do |f|
  f.association(:task)
  f.started_at { Time.now - 3600 }

  f.trait :closed do |t|
    t.ended_at { Time.now }
  end
end
