# frozen_string_literal: true

module ObjectStore
  Body = Data.define(:client, :key, :range) do
    def initialize(client:, key:, range: nil) = super

    def each(&) = client.stream(key, range: range && "bytes=#{range.begin}-#{range.end}", &)
  end
end
