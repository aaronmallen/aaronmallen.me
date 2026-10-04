# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :feed_subscribers do
      column :day, :date, null: false
      column :path, :http_path, null: false
      column :aggregator, :text, null: false
      column :subscribers, Integer, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      primary_key %i[day path aggregator]

      constraint(
        :feed_subscribers_aggregator_check,
        Sequel.lit("aggregator ~ '^[a-z0-9]+([._-][a-z0-9]+)*$' AND length(aggregator) <= 32"),
      )
      constraint(:feed_subscribers_subscribers_check) { subscribers >= 0 }
    end

    create_table :feed_readers do
      column :day, :date, null: false
      column :path, :http_path, null: false
      column :readers, Integer, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      primary_key %i[day path]

      constraint(:feed_readers_readers_check) { readers >= 0 }
    end

    create_table :feed_reader_hashes do
      column :day, :date, null: false
      column :path, :http_path, null: false
      column :reader_hash, :visitor_hash, null: false

      primary_key %i[day path reader_hash]
    end
  end
end
