# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :spam_senders do
      column :reply_to, :email_address, primary_key: true
      column :marked_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :spam_senders_reply_to_lower_check, Sequel.lit("reply_to = lower(reply_to)")
    end

    run <<~SQL
      INSERT INTO spam_senders (reply_to, marked_at)
      SELECT marked.reply_to, marked.marked_at
      FROM (
        SELECT lower(reply_to) AS reply_to, max(marked_spam_at) AS marked_at
        FROM messages
        WHERE status = 'spam'
        GROUP BY lower(reply_to)
      ) AS marked
      WHERE NOT EXISTS (
        SELECT 1
        FROM messages
        WHERE lower(messages.reply_to) = marked.reply_to
          AND messages.status <> 'spam'
          AND messages.updated_at > marked.marked_at
          AND messages.updated_at > messages.created_at
      );
    SQL
  end

  down do
    drop_table :spam_senders
  end
end
