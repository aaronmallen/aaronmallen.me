# frozen_string_literal: true

module Record
  module Linear
    class Client
      include Paging
      include Issues

      Error = Transport::Error
      RateLimited = Transport::RateLimited

      def initialize(transports:)
        @transports = transports
      end

      def configured? = transports.any?

      def inspect = "#<#{self.class.name} configured=#{configured?} workspaces=#{transports.size}>"

      private

      attr_reader :transports
    end
  end
end
