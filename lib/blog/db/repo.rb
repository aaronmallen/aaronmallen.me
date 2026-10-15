# frozen_string_literal: true

require "hanami/db/repo"

module Blog
  module DB
    class Repo < Hanami::DB::Repo
      module Tagged
        def add_tag(id, name)
          update(id, {}) unless taggings.tag(id, [name], tags).empty?
        end

        def by_id_for_update(id) = root.by_pk(id).lock.one

        def remove_tag(id, name)
          update(id, {}) if taggings.untag(id, [name], tags).positive?
        end

        def replace_tags(id, names) = taggings.retag(id, names, tags)
      end
      private_constant :Tagged

      STAMPED_COMMANDS = { create: :create, update: { update: :by_pk } }.freeze

      def self.stamped_commands(*types)
        types.each do |type|
          timestamps = Relation::STAMPS.fetch(type)

          commands(STAMPED_COMMANDS.fetch(type), use: :timestamps, plugins_options: { timestamps: { timestamps: } })
        end
      end

      def self.tagged_by(relation)
        include Tagged

        define_method(:taggings) { public_send(relation) }
        private :taggings
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
