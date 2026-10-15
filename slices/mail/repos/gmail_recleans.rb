# frozen_string_literal: true

module Mail
  module Repos
    class GmailRecleans < Blog::DB::Repo
      THREAD = Sequel[:mail_threads]
      COLUMNS = [THREAD[:id], :address, THREAD[:gmail_id]].freeze

      root :mail_threads

      def reclean(thread_id, messages)
        messages.each do |message|
          stored = mail_messages.where(mail_thread_id: thread_id, gmail_id: message[:gmail_id])
          stored.dataset.update(html_body: message[:html_body])
        end
      end

      def threads(addresses, after, limit)
        gmail = mail_threads.dataset.join(:mail_accounts, id: :mail_account_id)
        rows = gmail.where(address: addresses, provider: GmailMutations::GMAIL).exclude(THREAD[:gmail_id] => nil)
        rows.where(THREAD[:id] > after).order(THREAD[:id]).limit(limit).select_map(COLUMNS)
      end
    end
  end
end
