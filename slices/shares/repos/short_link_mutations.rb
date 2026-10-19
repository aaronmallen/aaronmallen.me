# frozen_string_literal: true

module Shares
  module Repos
    class ShortLinkMutations < Blog::DB::Repo
      include CodedMutations

      root :short_links

      stamped_commands :update

      def click(code)
        clicked = short_links.where(short_code_id: short_codes.resolved_id(code)).dataset
        counts = { click_count: Sequel[:click_count] + 1, last_clicked_at: Sequel::CURRENT_TIMESTAMP }
        clicked.returning(:destination).update(counts).first&.fetch(:destination)
      end

      def fill_title(id, destination, title)
        short_links.where(id:, destination:, title: nil).update(title:, updated_at: Time.now)
      end

      def hold_title_fetch(short_link_id) = held_title_fetches.hold(short_link_id)

      def lock_destination(destination) = short_links.lock_until_commit(Sequel.function(:hashtext, destination))

      def release_title_fetch(id) = held_title_fetches.by_pk(id).delete
    end
  end
end
