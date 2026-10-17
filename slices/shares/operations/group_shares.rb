# frozen_string_literal: true

module Shares
  module Operations
    class GroupShares < Blog::Operation
      FEWEST = 2
      TOO_FEW = "too_few"

      include Deps[
        "operations.add_shares_to_group",
        group_mutations: "repos.share_group_mutations",
        short_code_queries: "repos.short_code_queries",
      ]

      def call(ids)
        step enough(ids.uniq)

        transaction { step add_shares_to_group.call(create, ids) }
      end

      private

      def create(attempts = Helpers::Code::ATTEMPTS)
        group_mutations.create(code: short_code_queries.free_code)
      rescue ROM::SQL::UniqueConstraintError => e
        raise unless group_mutations.violated_constraint(e) == Helpers::Code::KEY && attempts > 1

        create(attempts - 1)
      end

      def enough(ids) = ids.size < FEWEST ? Failure([:invalid, { ids: [TOO_FEW] }]) : Success(ids)
    end
  end
end
