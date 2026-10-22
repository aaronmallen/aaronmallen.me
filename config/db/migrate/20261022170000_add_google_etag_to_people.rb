# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:people) { add_column :google_etag, :non_blank_text }
  end

  down do
    alter_table(:people) { drop_column :google_etag }
  end
end
