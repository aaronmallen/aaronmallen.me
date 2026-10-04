# frozen_string_literal: true

require "digest"

Spec::DB::Factories.define(:post_reader_hash) do |f|
  f.path "/writing/hello"
  f.sequence(:reader_hash) { |n| Digest::SHA256.hexdigest("reader #{n}") }
end
