# frozen_string_literal: true

module Activity
  module Structs
    JobEntry = Data.define(:name, :args, :queue, :at) do
      def self.from(record, at) = new(name: record.display_class, args: record.display_args, queue: record.queue, at:)

      def arguments = JSON.generate(args)[1...-1]
    end
  end
end
