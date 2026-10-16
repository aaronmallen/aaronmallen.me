# frozen_string_literal: true

ROM::SQL.migration do
  up do
    owned = from(:projects).exclude(repo: nil)
    rules = from(:task_rules).where(provider: "github")

    from(:task_rules).insert(
      %i[pattern provider],
      owned.exclude(repo: rules.select(:pattern)).select(:repo, Sequel.cast("github", :task_source_provider)),
    )

    from(:task_rule_projects).insert(
      %i[task_rule_id project_id],
      rules.join(:projects, repo: :pattern)
        .exclude(Sequel[:task_rules][:id] => from(:task_rule_projects).select(:task_rule_id))
        .select(Sequel[:task_rules][:id], Sequel[:projects][:id]),
    )
  end
end
