# frozen_string_literal: true

module Admin
  module Helpers
    module CommitMessage
      NEWLINE = "\n"
      PARTS = 2

      module_function

      def body(message)
        rest = message.to_s.split(NEWLINE, PARTS)[1].to_s.strip
        rest unless rest.empty?
      end

      def subject(message) = message.to_s.lines.first.to_s.strip
    end
  end
end
