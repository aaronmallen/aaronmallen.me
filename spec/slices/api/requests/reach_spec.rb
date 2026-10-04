# frozen_string_literal: true

RSpec.describe "API reach", type: :request do
  def self.exempt
    {
      "tasks.operations.act_on_tasks" => "the admin's bulk bar runs it; #341 adds the bulk task endpoints and tools",
      "tasks.operations.delete_task_comment" => "the admin deletes a comment; spec #65 gives clients only an add",
      "tasks.operations.delete_task_tag_rule" => "#393 adds the endpoint and tool that delete a tag rule",
      "tasks.operations.delete_work_session" => "#264 adds the endpoint and tool that delete a session",
      "tasks.operations.edit_work_session" => "#264 adds the endpoint and tool that edit a session",
      "tasks.operations.edit_task_comment" => "the admin edits a comment; spec #65 gives clients only an add",
      "tasks.operations.mark_task_seen" => "#339 adds the mark_task_seen endpoint and tool",
      "tasks.operations.place_task" => "the admin's drag places a task; reorder_task moves one a place up or down",
      "tasks.operations.queue_issue_sync" => "the admin's sync button queues the issue sync job",
      "tasks.operations.save_task_tag_rule" => "#393 adds the endpoint and tool that save a tag rule",
      "tasks.operations.set_task_total" => "#264 adds the endpoint and tool that set the total",
      "tasks.operations.sync_issues" => "a background job syncs the GitHub issues assigned to me",
    }
  end

  def actions
    Dir[API::Slice.root.join("actions", "**", "*.rb")].map do |path|
      relative = Pathname(path).relative_path_from(API::Slice.root).sub_ext("").to_s
      API::Slice[relative.tr("/", ".")]
    end
  end

  def exempt = self.class.exempt

  def operations
    { record: /journal/, tasks: // }.flat_map do |slice, pattern|
      names = Dir[Hanami.app.slices[slice].root.join("operations", "*.rb")].map { File.basename(it, ".rb") }

      names.grep(pattern).map { "#{slice}.operations.#{it}" }
    end
  end

  def reached(object, seen)
    object.instance_variables.map { object.instance_variable_get(it) }.each do |dependency|
      next unless walked?(dependency) && seen.add?(dependency.class)

      reached(dependency, seen)
    end
    seen
  end

  def reached_keys
    classes = actions.each_with_object(Set.new) { |action, seen| reached(action, seen) }
    operations.select { classes.include?(resolve(it).class) }
  end

  def resolve(key)
    slice, local = key.split(".", 2)
    Hanami.app.slices[slice.to_sym][local]
  end

  def walked?(dependency) = dependency.class.name.to_s.match?(/::(Endpoints|Operations)::/)

  it "reaches every journal and task operation from an endpoint unless the operation is exempt" do
    unreached = operations - reached_keys - exempt.keys

    expect(unreached).to be_empty, "no endpoint reaches these, and none is exempt:\n#{unreached.join("\n")}"
  end

  it "exempts only journal and task operations" do
    expect(exempt.keys - operations).to be_empty
  end

  it "exempts no operation an endpoint reaches" do
    expect(exempt.keys & reached_keys).to be_empty
  end

  it "gives every exempt operation a reason" do
    expect(exempt.select { |_, reason| reason.to_s.strip.empty? }.keys).to be_empty
  end
end
