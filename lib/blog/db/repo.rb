# frozen_string_literal: true

require "hanami/db/repo"

module Blog
  module DB
    class Repo < Hanami::DB::Repo
      STAMPED_COMMANDS = { create: :create, update: { update: :by_pk } }.freeze

      def self.stamped_commands(*types)
        types.each do |type|
          timestamps = Relation::STAMPS.fetch(type)

          commands(STAMPED_COMMANDS.fetch(type), use: :timestamps, plugins_options: { timestamps: { timestamps: } })
        end
      end

      def after_commit(&) = connection.after_commit(savepoint: true, &)

      def linkable(relation, **) = public_send(relation).find_linkable(**)

      def transaction(**, &) = super(savepoint: true, **, &)

      def violated_constraint(error) = connection.error_info(error.original_exception)[:constraint]

      private

      def connection = container.gateways[:default].connection
    end
  end
end
