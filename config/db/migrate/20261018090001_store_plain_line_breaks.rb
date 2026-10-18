# frozen_string_literal: true

ROM::SQL.migration do
  up do
    { posts: %i[body], social_post_parts: %i[body],
      suggestion_edits: %i[original replacement] }.each do |table, columns|
      columns.each do |column|
        plain = Sequel.function(:regexp_replace, column, "\r\n?", "\n", "g")
        from(table).where(Sequel.like(column, "%\r%")).update(column => plain)
      end
    end
  end
end
