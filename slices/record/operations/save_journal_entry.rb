# frozen_string_literal: true

module Record
  module Operations
    class SaveJournalEntry < Blog::Operation
      TIME_FORMAT = "%H:%M:%S"

      include Deps[contract: "contracts.journal_entry_contract", journal_entry_repo: "repos.journal_entry_repo"]

      def call(params, now: Time.now)
        attributes = step validate(params, now)
        step persist(attributes, now)
      end

      private

      def form(params) = { body: params[:body], entry_date: params[:entry_date], tags: params[:tags] }

      def invalid(field, code) = Failure([:invalid, { field => [code] }])

      def persist(attributes, now)
        time = Blog::TimeZone.local(now).strftime(TIME_FORMAT)

        id = transaction do
          entry = journal_entry_repo.create(**attributes.except(:tags), entry_time: time)
          journal_entry_repo.replace_tags(entry.id, attributes.fetch(:tags))
          entry.id
        end

        Success(journal_entry_repo.by_id(id))
      rescue ROM::SQL::CheckConstraintError
        invalid(:body, Contracts::JournalEntryContract::BLANK)
      end

      def validate(params, now)
        today = Blog::TimeZone.today(now)
        attributes = step validated(contract.call(form(params), today:))
        Success(attributes.merge(entry_date: attributes[:entry_date] || today))
      end
    end
  end
end
