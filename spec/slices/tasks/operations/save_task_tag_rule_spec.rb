# frozen_string_literal: true

RSpec.describe Tasks::Operations::SaveTaskTagRule do
  include Dry::Monads[:result]

  def private_tag(name) = Tasks::Slice["relations.tags"].where(name:, scope: "private").one

  def save(pattern, tags, id: nil) = Tasks::Slice["operations.save_task_tag_rule"].call({ pattern:, tags: }, id:)

  def sourced(repo, provider: "github", url: "https://github.com/#{repo}/issues/1")
    create(:task, :external).tap { create(:task_source, task: it, provider:, url:) }
  end

  def tag_names(*tasks) = tasks.map { Tasks::Slice["repos.task_repo"].by_id(it.id).tags.map(&:name) }

  def tagged(task, *names) = Tasks::Slice["repos.task_repo"].replace_tags(task.id, names)

  describe "a new rule" do
    it "creates each tag it names as a private tag", :aggregate_failures do
      rule = save("aaronmallen/*", "projects, new-tag").value!

      expect(rule.tags.map(&:name)).to eq(%w[new-tag projects])
      expect(private_tag("new-tag")).not_to be_nil
    end

    it "tags every task from a repo of that owner" do
      tasks = [sourced("aaronmallen/aaronmallen.me"), sourced("aaronmallen/other")]
      save("aaronmallen/*", "projects, new-tag")

      expect(tag_names(*tasks)).to all(eq(%w[new-tag projects]))
    end

    it "tags no task from another owner" do
      stranger = sourced("octocat/hello-world")
      save("aaronmallen/*", "projects")

      expect(tag_names(stranger)).to eq([[]])
    end

    it "tags no task without a source and no Linear task" do
      linear = sourced("aaronmallen/x", provider: "linear", url: "https://linear.app/aaronmallen/issue/ABC-1")
      plain = create(:task)
      save("aaronmallen/*", "projects")

      expect(tag_names(linear, plain)).to eq([[], []])
    end

    it "keeps its pattern lowercase" do
      expect(save("AaronMallen/AaronMallen.me", "ruby").value!.pattern).to eq("aaronmallen/aaronmallen.me")
    end

    it "matches only the repo a one repo pattern names" do
      tasks = [sourced("AaronMallen/AaronMallen.me"), sourced("aaronmallen/aaronmallen.me2")]
      save("AaronMallen/AaronMallen.me", "ruby")

      expect(tag_names(*tasks)).to eq([%w[ruby], []])
    end

    it "keeps a tag a task already has once" do
      site = sourced("aaronmallen/aaronmallen.me")
      tagged(site, "ruby")
      save("aaronmallen/*", "ruby, projects")

      expect(tag_names(site)).to eq([%w[projects ruby]])
    end

    it "records the tags on the task's timeline without marking it seen", :aggregate_failures do
      site = sourced("aaronmallen/aaronmallen.me")
      save("aaronmallen/*", "projects")

      expect(Tasks::Slice["relations.task_events"].where(task_id: site.id).pluck(:kind)).to eq(%w[tagged])
      expect(Tasks::Slice["repos.task_repo"].by_id(site.id).source.seen_at).to be_nil
    end
  end

  describe "a pattern that names neither one repo nor a whole owner" do
    %w[aaronmallen */foo aaronmallen/foo/bar].each do |pattern|
      it "refuses #{pattern} and keeps nothing", :aggregate_failures do
        expect(save(pattern, "ruby").failure).to eq([:invalid, { pattern: ["format"] }])
        expect(Tasks::Slice["relations.task_tag_rules"].count).to eq(0)
      end
    end
  end

  it "refuses a rule with no tags" do
    expect(save("aaronmallen/*", " , ").failure).to eq([:invalid, { tags: ["blank"] }])
  end

  it "refuses a pattern another rule holds" do
    save("aaronmallen/*", "ruby")

    expect(save("AaronMallen/*", "projects").failure).to eq([:invalid, { pattern: ["taken"] }])
  end

  describe "an edit" do
    let!(:rule) { save("aaronmallen/*", "projects").value! }

    it "changes the pattern and tags", :aggregate_failures do
      edited = save("aaronmallen/aaronmallen.me", "ruby, new-tag", id: rule.id).value!

      expect(edited).to have_attributes(id: rule.id, pattern: "aaronmallen/aaronmallen.me")
      expect(edited.tags.map(&:name)).to eq(%w[new-tag ruby])
    end

    it "creates a tag that does not exist as a private tag" do
      save("aaronmallen/*", "new-tag", id: rule.id)

      expect(private_tag("new-tag")).not_to be_nil
    end

    it "adds no tag to a task already imported" do
      site = sourced("aaronmallen/aaronmallen.me")
      save("aaronmallen/*", "projects, ruby", id: rule.id)

      expect(tag_names(site)).to eq([[]])
    end

    it "leaves off a tag the owner took off by hand" do
      site = sourced("aaronmallen/aaronmallen.me")
      tagged(site, "ruby")
      tagged(site)
      save("aaronmallen/*", "projects, ruby", id: rule.id)

      expect(tag_names(site)).to eq([[]])
    end

    it "answers not found for a missing rule" do
      expect(save("aaronmallen/*", "ruby", id: 0)).to eq(Failure(:not_found))
    end
  end
end
