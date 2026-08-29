# frozen_string_literal: true

require "hanami/db/repo"

module Blog
  module DB
    class Repo < Hanami::DB::Repo
      def after_commit(&) = connection.after_commit(savepoint: true, &)

      def transaction(**, &) = super(savepoint: true, **, &)

      def violated_constraint(error) = connection.error_info(error.original_exception)[:constraint]

      private

      def connection = container.gateways[:default].connection
    end
  end
end
