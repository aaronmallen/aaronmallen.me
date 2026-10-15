# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run <<~SQL
      CREATE INDEX mail_threads_waiting_starred_index ON mail_threads (mail_account_id)
        WHERE starred IS TRUE AND archived IS FALSE AND trashed IS FALSE AND draft IS FALSE;
      CREATE INDEX mail_threads_waiting_unread_index ON mail_threads (mail_account_id)
        WHERE status = 'unread' AND archived IS FALSE AND trashed IS FALSE AND draft IS FALSE;
    SQL
  end

  down do
    run <<~SQL
      DROP INDEX mail_threads_waiting_unread_index;
      DROP INDEX mail_threads_waiting_starred_index;
    SQL
  end
end
