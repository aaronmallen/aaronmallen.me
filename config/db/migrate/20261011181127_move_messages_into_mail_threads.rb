# frozen_string_literal: true

ROM::SQL.migration do
  zone = Blog::TimeZone::NAME
  messages_pattern = "\\s+UNION ALL\\s+SELECT\\s+''message''::text AS kind,.*FROM (public\\.)?messages\\M"
  mail_pattern = "\\s+UNION ALL\\s+SELECT\\s+''message''.*$"
  notified = %i[mail_accounts mail_threads mail_messages mail_thread_tags mail_labels mail_thread_labels]

  mail_branch = <<~SQL
    UNION ALL
    SELECT
      'message'::text,
      mail_threads.id,
      mail_threads.subject::text,
      coalesce(mail_messages.subject::text, '') || E'\\n' || coalesce(mail_messages.body::text, '') || E'\\n' ||
        coalesce(mail_messages.reply_to::text, ''),
      (mail_messages.received_at AT TIME ZONE '#{zone}')::date,
      mail_threads.status::text,
      NULL::text,
      NULL::text,
      NULL::text,
      NULL::text,
      mail_messages.search_vector
    FROM mail_messages
    JOIN mail_threads ON mail_threads.id = mail_messages.mail_thread_id
  SQL

  message_branch = <<~SQL
    UNION ALL
    SELECT
      'message'::text,
      messages.id,
      messages.subject::text,
      coalesce(messages.subject::text, '') || E'\\n' || coalesce(messages.body::text, '') || E'\\n' ||
        coalesce(messages.reply_to::text, ''),
      (messages.received_at AT TIME ZONE '#{zone}')::date,
      messages.status::text,
      NULL::text,
      NULL::text,
      NULL::text,
      NULL::text,
      messages.search_vector
    FROM messages
  SQL

  swap_branch = Kernel.lambda do |pattern, branch|
    <<~SQL
      DO $$
      DECLARE
        documents text := rtrim(pg_get_viewdef('search_documents'), E'; \\n');
        branch text := '#{pattern}';
      BEGIN
        IF documents !~ branch THEN
          RAISE EXCEPTION 'message branch not found in the search_documents view';
        END IF;
        DROP VIEW search_documents;
        EXECUTE 'CREATE VIEW search_documents AS ' || regexp_replace(documents, branch, '') || ' ' || $branch$#{branch}$branch$;
      END
      $$;
    SQL
  end

  search_vector = Kernel.lambda do |table|
    <<~SQL
      ALTER TABLE #{table} ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english'::regconfig, coalesce(subject::text, '')), 'A') ||
        setweight(to_tsvector('english'::regconfig, coalesce(body::text, '') || ' ' || coalesce(reply_to::text, '')), 'B')
      ) STORED;
      CREATE INDEX #{table}_search_vector_index ON #{table} USING gin (search_vector);
    SQL
  end

  up do
    create_enum :mail_provider, %w[contact_form gmail]

    create_table :mail_accounts do
      primary_key :id
      column :provider, :mail_provider, null: false
      column :name, :non_blank_text, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :provider, unique: true, where: { provider: "contact_form" }
    end

    create_table :mail_threads do
      primary_key :id
      foreign_key :mail_account_id, :mail_accounts, null: false, on_delete: :cascade
      column :subject, :non_blank_text, null: false
      column :status, :message_status, null: false, default: "unread"
      column :marked_spam_at, :timestamptz
      column :snoozed_until, :timestamptz
      column :received_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(:mail_threads_marked_spam_at_check, Sequel.lit("(status = 'spam') = (marked_spam_at IS NOT NULL)"))

      index :mail_account_id
      index %i[received_at id]
      index :status
      index :marked_spam_at
    end

    create_table :mail_messages do
      primary_key :id
      foreign_key :mail_thread_id, :mail_threads, null: false, on_delete: :cascade
      column :reply_to, :email_address, null: false
      column :subject, :non_blank_text, null: false
      column :body, :non_blank_text, null: false
      column :visitor_hash, :visitor_hash
      column :received_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index %i[mail_thread_id received_at]
      index %i[visitor_hash received_at]
      index :received_at
    end

    run search_vector.call(:mail_messages)

    create_table :mail_thread_tags do
      foreign_key :mail_thread_id, :mail_threads, null: false, on_delete: :cascade
      column :tag_id, Integer, null: false
      column :tag_scope, :tag_scope, null: false, default: "private"

      primary_key %i[mail_thread_id tag_id]

      foreign_key %i[tag_id tag_scope], :tags,
                  key: %i[id scope], on_delete: :cascade, name: :mail_thread_tags_tag_id_fkey
      constraint(:mail_thread_tags_tag_scope_check) { { tag_scope: "private" } }

      index :tag_id
    end

    create_table :mail_labels do
      primary_key :id
      foreign_key :mail_account_id, :mail_accounts, null: false, on_delete: :cascade
      column :name, :non_blank_text, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index %i[mail_account_id name], unique: true
    end

    create_table :mail_thread_labels do
      foreign_key :mail_thread_id, :mail_threads, null: false, on_delete: :cascade
      foreign_key :mail_label_id, :mail_labels, null: false, on_delete: :cascade

      primary_key %i[mail_thread_id mail_label_id]

      index :mail_label_id
    end

    run <<~SQL
      INSERT INTO mail_accounts (provider, name) VALUES ('contact_form', 'Contact form');

      INSERT INTO mail_threads (
        id, mail_account_id, subject, status, marked_spam_at, snoozed_until, received_at, created_at, updated_at
      )
      SELECT messages.id, mail_accounts.id, messages.subject, messages.status, messages.marked_spam_at,
        messages.snoozed_until, messages.received_at, messages.created_at, messages.updated_at
      FROM messages CROSS JOIN mail_accounts;

      INSERT INTO mail_messages (
        id, mail_thread_id, reply_to, subject, body, visitor_hash, received_at, created_at, updated_at
      )
      SELECT id, id, reply_to, subject, body, visitor_hash, received_at, created_at, updated_at FROM messages;

      INSERT INTO mail_thread_tags (mail_thread_id, tag_id, tag_scope)
      SELECT message_id, tag_id, tag_scope FROM message_tags;

      SELECT setval(pg_get_serial_sequence('mail_threads', 'id'), last_value, is_called) FROM messages_id_seq;
      SELECT setval(pg_get_serial_sequence('mail_messages', 'id'), last_value, is_called) FROM messages_id_seq;
    SQL

    run swap_branch.call(messages_pattern, mail_branch)

    run(notified.map do |table|
      "CREATE TRIGGER #{table}_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON #{table} " \
        "FOR EACH ROW EXECUTE FUNCTION notify_admin_change();"
    end.join("\n"))

    drop_table :message_tags, :messages
  end

  down do
    run <<~SQL
      CREATE TABLE messages (
        id integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
        reply_to email_address NOT NULL,
        subject non_blank_text NOT NULL,
        body non_blank_text NOT NULL,
        status message_status DEFAULT 'unread' NOT NULL,
        visitor_hash visitor_hash NOT NULL,
        received_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
        created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
        updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
        marked_spam_at timestamptz,
        search_vector tsvector GENERATED ALWAYS AS (
          setweight(to_tsvector('english'::regconfig, coalesce(subject::text, '')), 'A') ||
          setweight(to_tsvector('english'::regconfig, coalesce(body::text, '') || ' ' || coalesce(reply_to::text, '')), 'B')
        ) STORED,
        snoozed_until timestamptz,
        CONSTRAINT messages_marked_spam_at_check CHECK ((status = 'spam') = (marked_spam_at IS NOT NULL))
      );
      CREATE INDEX messages_marked_spam_at_index ON messages (marked_spam_at);
      CREATE INDEX messages_received_at_id_index ON messages (received_at, id);
      CREATE INDEX messages_search_vector_index ON messages USING gin (search_vector);
      CREATE INDEX messages_status_index ON messages (status);
      CREATE INDEX messages_visitor_hash_received_at_index ON messages (visitor_hash, received_at);
    SQL

    create_table :message_tags do
      foreign_key :message_id, :messages, null: false, on_delete: :cascade
      column :tag_id, Integer, null: false
      column :tag_scope, :tag_scope, null: false, default: "private"

      primary_key %i[message_id tag_id]

      foreign_key %i[tag_id tag_scope], :tags, key: %i[id scope], on_delete: :cascade, name: :message_tags_tag_id_fkey
      constraint(:message_tags_tag_scope_check) { { tag_scope: "private" } }

      index :tag_id
    end

    run <<~SQL
      INSERT INTO messages (
        id, reply_to, subject, body, status, visitor_hash, received_at, created_at, updated_at, marked_spam_at,
        snoozed_until
      )
      SELECT DISTINCT ON (mail_threads.id) mail_threads.id, mail_messages.reply_to, mail_threads.subject,
        mail_messages.body, mail_threads.status, mail_messages.visitor_hash, mail_threads.received_at,
        mail_threads.created_at, mail_threads.updated_at, mail_threads.marked_spam_at, mail_threads.snoozed_until
      FROM mail_threads
      JOIN mail_accounts ON mail_accounts.id = mail_threads.mail_account_id AND mail_accounts.provider = 'contact_form'
      JOIN mail_messages ON mail_messages.mail_thread_id = mail_threads.id
      ORDER BY mail_threads.id, mail_messages.received_at, mail_messages.id;

      INSERT INTO message_tags (message_id, tag_id, tag_scope)
      SELECT mail_thread_id, tag_id, tag_scope FROM mail_thread_tags WHERE mail_thread_id IN (SELECT id FROM messages);

      SELECT setval('messages_id_seq', last_value, is_called) FROM mail_threads_id_seq;

      CREATE TRIGGER messages_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON messages
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
      CREATE TRIGGER message_tags_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON message_tags
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL

    run swap_branch.call(mail_pattern, message_branch)

    drop_table(*notified.reverse)
    drop_enum :mail_provider
  end
end
