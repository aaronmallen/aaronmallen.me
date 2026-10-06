# frozen_string_literal: true

Spec::DB::Factories.define(:task_contributor) do |f|
  f.association(:task)
  f.kind "agent"
  f.agent "claude-code"
  f.model "claude-opus-5-5"

  f.trait :owner do |t|
    t.kind "owner"
    t.agent nil
    t.model nil
  end
end
