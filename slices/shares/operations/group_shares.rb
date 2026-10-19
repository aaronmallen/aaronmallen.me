# frozen_string_literal: true

module Shares
  module Operations
    class GroupShares < Blog::Operation
      FEWEST = 2
      TOO_FEW = "too_few"

      include Deps[
        "operations.add_shares_to_group",
        group_mutations: "repos.share_group_mutations",
      ]

      def call(ids)
        step enough(ids.uniq)

        transaction { step add_shares_to_group.call(create, ids) }
      end

      private

      def create
        Helpers::Code.retrying(group_mutations) { group_mutations.create }
      end

      def enough(ids) = ids.size < FEWEST ? invalid(:ids, TOO_FEW) : Success(ids)
    end
  end
end
