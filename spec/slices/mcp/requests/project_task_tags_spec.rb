# frozen_string_literal: true

RSpec.describe "MCP tags on project tasks", type: :request do
  let(:client) { Spec::IssueClient.new }
  let(:podcast) { create(:project, name: "Podcast", key: "POD") }

  def held(task)
    found = Tasks::Slice["relations.task_tags"].dataset.unordered.join(:tags, id: :tag_id).where(task_id: task.id)

    found.order(:name).select_map([:name, :scope, Sequel[:tags][:project_id]])
  end

  def history(task) = Tasks::Slice["relations.task_events"].where(task_id: task.id).pluck(:kind, :tag_name)

  def import(origin)
    client.assigned << {
      body: "", id: "I_1", origin:, reference: "#{origin}#1", remote_state: "open", title: "Fix it",
      url: "https://github.com/#{origin}/issues/1",
    }
    Tasks::Slice["operations.sync_issues"].call(provider: "github", client:)
    newest
  end

  def mcp_scopes = %w[read write publish delete]

  def newest = Tasks::Slice["repos.task_queries"].by_id(Tasks::Slice["relations.tasks"].unordered.max(:id))

  def project_tag(name, project, **) = create(:tag, name:, scope: "project", project_id: project.id, **)

  def tagged(task, *names) = Tasks::Slice["repos.task_mutations"].replace_tags(task.id, names)

  it "makes a project tag when save_task tags a project task" do
    task = create(:task, project_id: podcast.id)
    mcp_call("save_task", id: task.id, tags: %w[audio])

    expect(held(task)).to eq([["audio", "project", podcast.id]])
  end

  it "uses the project's tag of that name and makes no global one", :aggregate_failures do
    tag = project_tag("audio", podcast)
    task = create(:task, project_id: podcast.id)
    mcp_call("save_task", id: task.id, tags: %w[audio])

    expect(Tasks::Slice["relations.task_tags"].where(task_id: task.id).pluck(:tag_id)).to eq([tag.id])
    expect(Tags::Slice["repos.tag_queries"].all_in("private")).to be_empty
  end

  it "tags each task in its own scope with tag_tasks" do
    inside = create(:task, project_id: podcast.id)
    loose = create(:task)
    mcp_call("tag_tasks", ids: [inside.id, loose.id], tag: "audio")

    expect([held(inside), held(loose)]).to eq([[["audio", "project", podcast.id]], [["audio", "private", nil]]])
  end

  it "takes a project tag off with untag_tasks and notes it in the history", :aggregate_failures do
    task = create(:task, project_id: podcast.id)
    tagged(task, "audio")
    mcp_call("untag_tasks", ids: [task.id], tag: "audio")

    expect(held(task)).to be_empty
    expect(history(task)).to eq([%w[untagged audio]])
  end

  it "makes project tags for a task capture_task files into a project" do
    podcast
    mcp_call("capture_task", title: "Record the intro", project: "POD", tags: %w[audio])

    expect(held(newest)).to eq([["audio", "project", podcast.id]])
  end

  describe "a task that moves to another project" do
    let(:blog) { create(:project, name: "Blog", key: "BLOG") }
    let(:task) { create(:task, project_id: podcast.id) }

    before do
      project_tag("audio", podcast, color: "mk-violet", description: "Sound work")
      project_tag("video", podcast, color: "mk-green")
      project_tag("video", blog, color: "mk-sand")
      tagged(task, "audio", "video")
      mcp_call("link_records", kind: "task", id: task.id, other_kind: "project", other_id: blog.id)
    end

    it "carries its tags by name into the new project" do
      expect(held(task)).to eq([["audio", "project", blog.id], ["video", "project", blog.id]])
    end

    it "makes a missing tag with the old tag's tone and description" do
      made = Tags::Slice["repos.tag_queries"].all_in("project", project_id: blog.id).find { it.name == "audio" }

      expect(made.to_h.slice(:color, :description)).to eq(color: "mk-violet", description: "Sound work")
    end

    it "keeps the new project's own tag of a name it holds" do
      kept = Tags::Slice["repos.tag_queries"].all_in("project", project_id: blog.id).find { it.name == "video" }

      expect(kept.color).to eq("mk-sand")
    end
  end

  it "keeps a task's tags as global tags when it leaves every project" do
    task = create(:task, project_id: podcast.id)
    tagged(task, "audio")
    mcp_call("unlink_records", kind: "task", id: task.id, other_kind: "project", other_id: podcast.id)

    expect(held(task)).to eq([["audio", "private", nil]])
  end

  describe "a rule that files into a project" do
    before do
      Tasks::Slice["operations.save_task_rule"].call({ pattern: "acme/*", tags: "audio", projects: [podcast.id] })
    end

    it "holds that project's tags" do
      rule = Tasks::Slice["repos.task_rule_queries"].all.first

      expect(rule.tags.map { [it.name, it.scope, it.project_id] }).to eq([["audio", "project", podcast.id]])
    end

    it "gives a new task its project's tags and notes them in the history", :aggregate_failures do
      task = import("acme/site")

      expect(held(task)).to eq([["audio", "project", podcast.id]])
      expect(history(task)).to eq([%w[tagged audio]])
    end

    it "makes the tags of a rule that files elsewhere in the new task's project" do
      blog = create(:project, key: "BLOG")
      Tasks::Slice["operations.save_task_rule"].call({ pattern: "acme/site", tags: "", projects: [blog.id] })

      expect(held(import("acme/site"))).to eq([["audio", "project", blog.id]])
    end
  end
end
