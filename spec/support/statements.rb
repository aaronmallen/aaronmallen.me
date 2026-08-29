# frozen_string_literal: true

module Spec
  module Statements
    STATEMENT = /INSERT INTO|SELECT|UPDATE|DELETE FROM/

    class Listener
      attr_reader :queries

      def initialize
        @queries = []
      end

      def on_sql(event)
        queries << event[:query]
      end
    end

    def counting
      listener = Listener.new
      notifications = Hanami.app["notifications"]
      notifications.subscribe(listener)
      yield

      listener.queries.grep(STATEMENT)
    ensure
      notifications&.unsubscribe(listener)
    end
  end
end

RSpec.configure do |config|
  config.include Spec::Statements
end
