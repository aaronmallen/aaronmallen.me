# frozen_string_literal: true

module Shares
  module Repos
    class ShareGroupMutations < Blog::DB::Repo
      root :share_groups

      def add_file(share_group_id, **fields) = share_group_files.command(:create).call(share_group_id:, **fields)

      def change_code(short_code_id, code)
        short_codes.by_pk(short_code_id).command(:update).call(code:, updated_at: Time.now)
      end

      def count_file_download(id) = share_group_files.by_pk(id).update(download_count: Sequel[:download_count] + 1)

      def count_view(id) = share_groups.by_pk(id).update(view_count: Sequel[:view_count] + 1)

      def count_zip_download(id) = share_groups.by_pk(id).update(zip_download_count: Sequel[:zip_download_count] + 1)

      def create(code:)
        transaction do
          short_code = short_codes.command(:create).call(code:)
          share_groups.command(:create).call(short_code_id: short_code.id).id
        end
      end

      def delete(short_code_id) = short_codes.by_pk(short_code_id).delete

      def join(file_id, group_id, short_code_id)
        transaction do
          share_group_files.by_pk(file_id).update(share_group_id: group_id, short_code_id: nil, updated_at: Time.now)
          short_codes.by_pk(short_code_id).delete
        end
      end

      def leave(file_id, code:)
        transaction do
          short_code = short_codes.command(:create).call(code:)
          share_group_files.by_pk(file_id).update(short_code_id: short_code.id, share_group_id: nil,
                                                  updated_at: Time.now)
        end
      end

      def name(id, name) = share_groups.by_pk(id).update(name:, updated_at: Time.now)

      def remove_file(id) = share_group_files.by_pk(id).delete

      def update_file(id, **) = share_group_files.by_pk(id).update(**, updated_at: Time.now)
    end
  end
end
