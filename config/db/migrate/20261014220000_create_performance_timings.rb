# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :performance_job_outcome, %w[succeeded failed]

    create_table :performance_requests do
      primary_key :id
      column :route, :http_path
      column :verb, :text, null: false
      column :status, :smallint, null: false
      column :duration, :double, null: false
      column :query_count, :integer, null: false
      column :query_time, :double, null: false
      column :occurred_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(:performance_requests_duration_check) { duration >= 0 }
      constraint(:performance_requests_query_count_check) { query_count >= 0 }
      constraint(:performance_requests_query_time_check) { query_time >= 0 }

      index :occurred_at
    end

    create_table :performance_jobs do
      primary_key :id
      column :job, :text, null: false
      column :outcome, :performance_job_outcome, null: false
      column :duration, :double, null: false
      column :query_count, :integer, null: false
      column :query_time, :double, null: false
      column :occurred_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(:performance_jobs_duration_check) { duration >= 0 }
      constraint(:performance_jobs_query_count_check) { query_count >= 0 }
      constraint(:performance_jobs_query_time_check) { query_time >= 0 }

      index :occurred_at
    end
  end

  down do
    drop_table :performance_jobs, :performance_requests
    drop_enum :performance_job_outcome
  end
end
