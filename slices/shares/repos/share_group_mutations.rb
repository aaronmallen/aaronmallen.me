# frozen_string_literal: true

module Shares
  module Repos
    class ShareGroupMutations < Blog::DB::Repo
      root :share_groups

      def add_file(share_group_id, **fields) = share_group_files.command(:create).call(share_group_id:, **fields)

      def create(code:)
        transaction do
          short_code = short_codes.command(:create).call(code:)
          share_groups.command(:create).call(short_code_id: short_code.id).id
        end
      end
    end
  end
end
