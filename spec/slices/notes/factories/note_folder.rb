# frozen_string_literal: true

Spec::DB::Factories.define(:note_folder) do |f|
  f.sequence(:name) { |n| "Folder #{n}" }
end
