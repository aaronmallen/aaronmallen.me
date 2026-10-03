# frozen_string_literal: true

Spec::DB::Factories.define(:saved_view) do |f|
  f.sequence(:name) { |n| "View #{n}" }
  f.screen "tasks"
  f.filters { {} }
end
