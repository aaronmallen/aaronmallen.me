# frozen_string_literal: true

module Admin
  module Structs
    ServiceRow = Data.define(:key, :definition, :connection, :env, :jobs, :status) do
      def account = connection&.label || definition.account

      def failing_jobs = jobs.select { it[:failure] }
    end
  end
end
