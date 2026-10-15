# frozen_string_literal: true

Spec::DB::Factories.define(:post_edit) do |f|
  f.association(:post)
  f.note { Faker::Lorem.sentence }
  f.note_html { |note| Markdown.to_html(note) }
end
