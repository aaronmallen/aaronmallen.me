# frozen_string_literal: true

module Security
  module Relations
    class Devices < Blog::DB::Relation
      LAST_SIGN_IN = %i[provider address city country country_name].freeze
      SIGNED_IN = Blog::Types::SignInOutcome["signed_in"]

      schema :devices, infer: true

      def newest_first = order(self[:last_signed_in_at].desc, self[:id].desc)

      def sign_in(id, **device)
        row = { **device, last_signed_in_at: Sequel::CURRENT_TIMESTAMP }
        found = where(id:).dataset.returning(:id).update(row).first if id

        (found || dataset.returning(:id).insert(row).first).fetch(:id)
      end

      def signed_in_before(time) = where { last_signed_in_at < time }

      def with_last_sign_in = select_append(*LAST_SIGN_IN.map { last_sign_in(it) })

      private

      def last_sign_in(column)
        last = dataset.db[:sign_ins].where(device_id: self[:id].qualified, outcome: SIGNED_IN)
                      .order(Sequel.desc(:created_at), Sequel.desc(:id)).limit(1).select(column)

        ROM::SQL::Attribute[ROM::Types::String].meta(sql_expr: last).as(column)
      end
    end
  end
end
