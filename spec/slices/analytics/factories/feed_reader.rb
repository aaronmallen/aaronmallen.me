# frozen_string_literal: true

Spec::DB::Factories.define(:feed_reader) do |f|
  f.day { Blog::TimeZone.today }
  f.path "/writing.atom"
  f.readers 1
end
