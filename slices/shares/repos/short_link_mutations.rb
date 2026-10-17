# frozen_string_literal: true

module Shares
  module Repos
    class ShortLinkMutations < Blog::DB::Repo
      root :short_links

      stamped_commands :update

      def change_code(short_code_id, code)
        short_codes.by_pk(short_code_id).command(:update).call(code:, updated_at: Time.now)
      end

      def click(code)
        clicked = short_links.where(short_code_id: short_codes.where(code:).select(:id).dataset).dataset
        counts = { click_count: Sequel[:click_count] + 1, last_clicked_at: Sequel::CURRENT_TIMESTAMP }
        clicked.returning(:destination).update(counts).first&.fetch(:destination)
      end

      def create(code:, **fields)
        transaction do
          short_code = short_codes.command(:create).call(code:)
          short_links.command(:create).call(short_code_id: short_code.id, **fields).id
        end
      end

      def delete(short_code_id) = short_codes.by_pk(short_code_id).delete

      def fill_title(id, destination, title)
        short_links.where(id:, destination:, title: nil).update(title:, updated_at: Time.now)
      end

      def hold_title_fetch(short_link_id) = held_title_fetches.hold(short_link_id)

      def lock_destination(destination) = short_links.lock_until_commit(Sequel.function(:hashtext, destination))

      def release_title_fetch(id) = held_title_fetches.by_pk(id).delete
    end
  end
end
