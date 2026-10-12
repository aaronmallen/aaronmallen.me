# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :mail_attachments do
      foreign_key :mail_message_id, :mail_messages, null: false, on_delete: :cascade
      column :part_id, :text, null: false
      column :filename, :non_blank_text, null: false
      column :mime_type, :text, null: false
      column :size, Integer, null: false

      primary_key %i[mail_message_id part_id]
    end
  end
end
