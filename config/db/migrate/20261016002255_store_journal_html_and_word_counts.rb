# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:journal_entries) do
      add_column :body_html, :text, null: false, default: ""
      add_column :word_count, :integer, null: false, generated_always_as: Sequel.function(:regexp_count, :body, "\\S+")
    end

    from(:journal_entries).select(:id, :body).all.each do |entry|
      from(:journal_entries).where(id: entry[:id]).update(body_html: Markdown.to_html(entry[:body]))
    end

    alter_table(:journal_entries) { set_column_default :body_html, nil }
  end

  down do
    alter_table(:journal_entries) do
      drop_column :word_count
      drop_column :body_html
    end
  end
end
