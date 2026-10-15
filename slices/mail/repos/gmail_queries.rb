# frozen_string_literal: true

module Mail
  module Repos
    class GmailQueries < Blog::DB::Repo
      def address(account_id)
        mail_accounts.where(id: account_id, provider: GmailMutations::GMAIL).pluck(:address).first
      end

      def label_ids(account_id) = mail_labels.where(mail_account_id: account_id).pluck(:gmail_id)

      def label_named(account_id, name) = mail_labels.where(mail_account_id: account_id, name:).one
    end
  end
end
