# frozen_string_literal: true

module Links
  module Operations
    class LinkRecords < Operation
      CONSTRAINTS = {
        "record_links_order_check" => [:other_id, "self"],
        "record_links_pair_key" => [:other_id, "taken"],
        "record_links_record_missing" => [:other_id, "missing"],
        "record_links_task_pair_check" => [:other_id, "task_pair"],
      }.freeze
      FIELDS = %i[other_kind other_id].freeze

      include Deps[
        records: "queries.linkable_records",
        contract: "contracts.record_link_contract",
        record_link_repo: "repos.record_link_repo",
      ]

      def call(kind, id, params)
        side = step find(kind, id)
        fields = step validate(params)

        step persist(side, fields.values_at(*FIELDS))
      end

      private

      def find(kind, id)
        id = Blog::Types::IdParam[id]
        known = id && Blog::Types::RecordKind.valid?(kind) && records.named(kind, [id]).any?

        found(known && [kind, id])
      end

      def form(params) = FIELDS.to_h { [it, params[it]] }

      def persist(side, other)
        Success(transaction { record_link_repo.link(side, other) })
      rescue ROM::SQL::UniqueConstraintError, ROM::SQL::CheckConstraintError, ROM::SQL::ForeignKeyConstraintError => e
        field, code = CONSTRAINTS[record_link_repo.violated_constraint(e)]
        raise unless field

        Failure([:invalid, { field => [code] }])
      end

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
