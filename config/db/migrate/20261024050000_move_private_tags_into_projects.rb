# frozen_string_literal: true

ROM::SQL.migration do
  up do
    linked = Kernel.lambda do |kind|
      links = from(:record_links)
      left = links.where(left_kind: "project", right_kind: kind).select(Sequel[:right_id].as(:owner), Sequel[:left_id])
      right = links.where(left_kind: kind, right_kind: "project").select(Sequel[:left_id].as(:owner), :right_id)

      left.union(right, all: true, alias: :related).select(:owner, Sequel[:left_id].as(:project_id))
    end
    owned = Kernel.lambda do |table|
      from(table).exclude(project_id: nil).select(Sequel[:id].as(:owner), :project_id)
    end

    related = {
      task_tags: [:task_id, owned.call(:tasks)],
      task_rule_tags: [:task_rule_id, from(:task_rule_projects).select(Sequel[:task_rule_id].as(:owner), :project_id)],
      agent_session_tags: [:agent_session_id, owned.call(:agent_sessions)],
      memory_file_tags: [:memory_file_id, owned.call(:memory_files)],
      decision_tags: [:decision_id, linked.call("decision")],
      journal_entry_tags: [:journal_entry_id, linked.call("journal_entry")],
      mail_thread_tags: [:mail_thread_id, linked.call("mail_thread")],
      note_tags: [:note_id, linked.call("note")],
      artifact_tags: [:artifact_id, linked.call("artifact")],
    }
    moved = []

    related.each do |table, (owner_key, projects)|
      owner = Sequel[table][owner_key]
      tag = Sequel[:tags]
      project = Sequel.cast("project", :tag_scope)
      project_id = Sequel[:related][:project_id]
      held = from(table).join(projects, { owner: }, table_alias: :related).join(:tags, id: Sequel[table][:tag_id])
      held = held.where(Sequel[table][:tag_scope] => "private")
      copies = held.join(Sequel[:tags].as(:copy), scope: project, project_id:, name: tag[:name])

      from(:tags).insert_conflict.insert(
        %i[name color description scope project_id],
        held.distinct.select(tag[:name], tag[:color], tag[:description], project, project_id),
      )
      from(table).insert_conflict.insert(
        [owner_key, :tag_id, :tag_scope], copies.distinct.select(owner, Sequel[:copy][:id], Sequel[:copy][:scope]),
      )
      moved |= held.distinct.select_map(Sequel[table][:tag_id])
      from(table).where(tag_scope: "private", owner_key => projects.from_self.select(:owner)).delete
    end

    from(:tags).where(id: moved).exclude(
      related.keys.map { Sequel.expr(id: from(it).select(:tag_id)) }.reduce(:|),
    ).delete
  end
end
