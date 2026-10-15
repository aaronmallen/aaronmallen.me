# frozen_string_literal: true

module Mail
  module Repos
    class GmailBackfills < Blog::DB::Repo
      root :mail_accounts

      def hold(address, page, at: Time.now)
        mail_accounts.where(address:).dataset.update(backfill_page: page, backfill_held_at: at)
      end

      def resume(stalled_before, now: Time.now)
        stalled = mail_accounts.where(Sequel[:backfill_held_at] < stalled_before).dataset

        stalled.returning(:address, :backfill_page).update(backfill_held_at: now).map(&:values)
      end
    end
  end
end
