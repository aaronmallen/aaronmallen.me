# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:posts) do
      add_column :body_html, :text, null: false, default: ""
      add_column :first_paragraph, :text
      add_column :read_time, :integer, null: false, default: 1
      add_column :word_count, :integer, null: false, default: 0
    end
    alter_table(:post_edits) { add_column :note_html, :text, null: false, default: "" }

    from(:posts).select(:id, :body).all.each do |post|
      document = Markdown::Document.new(post[:body])
      from(:posts).where(id: post[:id]).update(
        body_html: document.html, first_paragraph: document.first_paragraph, read_time: document.read_time,
        word_count: document.word_count,
      )
    end
    from(:post_edits).select(:id, :note).all.each do |edit|
      from(:post_edits).where(id: edit[:id]).update(note_html: Markdown.to_html(edit[:note]))
    end

    alter_table(:posts) do
      set_column_default :body_html, nil
      set_column_default :read_time, nil
      set_column_default :word_count, nil
    end
    alter_table(:post_edits) { set_column_default :note_html, nil }
  end

  down do
    alter_table(:post_edits) { drop_column :note_html }
    alter_table(:posts) do
      drop_column :word_count
      drop_column :read_time
      drop_column :first_paragraph
      drop_column :body_html
    end
  end
end
