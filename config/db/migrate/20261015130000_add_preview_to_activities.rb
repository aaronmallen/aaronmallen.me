# frozen_string_literal: true

ROM::SQL.migration do
  previews = {
    "journal_entries" => "left(journal_entries.body, 1000)",
    "task_comments" => "left(task_comments.body::text, 1000)",
    "decision_comments" => "left(decision_comments.body::text, 1000)",
  }
  branch = /AS contributors(?<from>\s+FROM \(*(?:public\.)?(?<table>\w+))/

  up do
    definition = fetch("SELECT pg_get_viewdef('activities') AS sql").single_value.chomp(";")
    found = []
    added = definition.gsub(branch) do
      match = Regexp.last_match
      found << match[:table]

      "AS contributors,\n    #{previews.fetch(match[:table], 'NULL::text')} AS preview#{match[:from]}"
    end
    raise "the activities view lacks a branch for #{previews.keys - found}" unless (previews.keys - found).empty?

    run "CREATE OR REPLACE VIEW activities AS #{added}"
  end

  down do
    definition = fetch("SELECT pg_get_viewdef('activities') AS sql").single_value.chomp(";")

    run "DROP VIEW activities"
    run "CREATE VIEW activities AS #{definition.gsub(/,\n[^\n]* AS preview$/, '')}"
  end
end
