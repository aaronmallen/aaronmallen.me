# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run "ALTER DOMAIN short_code DROP CONSTRAINT short_code_length"
  end

  down do
    run "ALTER DOMAIN short_code ADD CONSTRAINT short_code_length CHECK (char_length(VALUE) >= 8) NOT VALID"
  end
end
