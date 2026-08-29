# frozen_string_literal: true

require "stringio"

module Spec
  module Stdout
    class << self
      def capture = ($stdout = @capture ||= StringIO.new)

      def release
        $stdout = STDOUT
        @capture.string
      end
    end
  end
end

Spec::Stdout.capture

RSpec.configure do |config|
  config.after(:suite) do
    stray = Spec::Stdout.release

    raise "the suite wrote this to stdout, where nobody reads it:\n\n#{stray}" unless stray.empty?
  end
end
