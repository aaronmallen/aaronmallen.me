# frozen_string_literal: true

module Contacts
  module Relations
    class People < Blog::DB::Relation
      GOOGLE_FIELDS = %i[
        name name_prefix given_name middle_name family_name name_suffix
        phonetic_given_name phonetic_middle_name phonetic_family_name
        nickname file_as company job_title department notes
        emails phones addresses websites chats dates relations custom_fields birthday labels starred
        google_etag updated_at
      ].freeze
      LISTS = %i[emails phones addresses websites chats dates relations custom_fields].freeze
      SEARCHED = %i[name nickname key company job_title mastodon_handle bluesky_handle].freeze

      schema :people, infer: true

      def emailed = where(Sequel.function(:jsonb_array_length, :emails) => 1..)

      def in_file_order = order(Sequel.function(:coalesce, :file_as, :name, :company).asc, self[:id].asc)

      def in_name_order = order(self[:name].asc, self[:key].asc)

      def label_names = dataset.unordered.select(Sequel.function(:unnest, :labels).as(:label)).distinct.order(:label)

      def labeled(label) = where(Sequel.expr(label => Sequel.pg_array_op(:labels).any))

      def matching(text) = containing(text, *SEARCHED, values(:emails), values(:phones))

      def mentionable = exclude(key: nil)

      def starred = where(starred: true)

      def store(google_connection_id, rows, now:)
        rows = rows.map do |row|
          row.merge(
            **row.slice(*LISTS).transform_values { Sequel.cast(JSON.generate(it), :jsonb) },
            labels: Sequel.pg_array(row[:labels], :text), google_connection_id:, created_at: now, updated_at: now,
          )
        end

        upsert = dataset.insert_conflict(target: %i[google_connection_id google_id], update: excluded(GOOGLE_FIELDS))
        upsert.multi_insert(rows)
      end

      def with_email(address) = where(Sequel.function(:lower, address) => dataset.db.select(emails))

      private

      def emails
        values = Sequel.function(:jsonb_path_query_array, :emails, "$[*].value")
        Sequel.function(:lower, Sequel.function(:jsonb_array_elements_text, values))
      end

      def values(list) = Sequel.function(:jsonb_path_query_array, list, "$[*].value").cast(:text)
    end
  end
end
