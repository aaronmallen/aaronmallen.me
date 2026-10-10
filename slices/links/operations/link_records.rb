# frozen_string_literal: true

module Links
  module Operations
    class LinkRecords < Blog::Operation
      CONSTRAINTS = {
        "record_links_order_check" => [:other_id, "self"],
        "record_links_pair_key" => [:other_id, "taken"],
        "record_links_record_missing" => [:other_id, "missing"],
        "record_links_task_pair_check" => [:other_id, "task_pair"],
      }.freeze

      include Deps[
        records: "repos.record_link_queries",
        contract: "contracts.record_link_contract",
        record_link_mutations: "repos.record_link_mutations",
      ]

      def call(kind, id, params)
        side = step find(kind, id)
        fields = step validate(params)

        step persist(side, fields.values_at(:other_kind, :other_id))
      end

      private

      def find(kind, id)
        id = Blog::Types::IdParam[id]
        known = id && Blog::Types::RecordKind.valid?(kind) && records.named(kind, [id]).any?

        found(known && [kind, id])
      end

      def persist(side, other)
        Success(transaction { record_link_mutations.link(side, other) })
      rescue ROM::SQL::UniqueConstraintError, ROM::SQL::CheckConstraintError, ROM::SQL::ForeignKeyConstraintError => e
        field, code = CONSTRAINTS[record_link_mutations.violated_constraint(e)]
        raise unless field

        Failure([:invalid, { field => [code] }])
      end

      def validate(params) = validated(contract.call(every_field(params)))
    end
  end
end
