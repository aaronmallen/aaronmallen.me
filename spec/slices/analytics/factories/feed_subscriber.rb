# frozen_string_literal: true

Spec::DB::Factories.define(:feed_subscriber) do |f|
  f.day { Blog::TimeZone.today }
  f.path "/writing.atom"
  f.aggregator "feedly"
  f.subscribers 42
end
