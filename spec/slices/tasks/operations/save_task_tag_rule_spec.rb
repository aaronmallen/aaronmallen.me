# frozen_string_literal: true

RSpec.describe Tasks::Operations::SaveTaskTagRule do
  def linear(workspace, key) = sourced("https://linear.app/#{workspace}/issue/#{key}/sync-my-issues")

  def save(fields, id: nil) = Tasks::Slice["operations.save_task_tag_rule"].call(fields, id:)

  def sourced(url, provider: "linear")
    create(:task, :external).tap { create(:task_source, task: it, provider:, url:) }
  end

  def tag_names(task) = Tasks::Slice["repos.task_repo"].by_id(task.id).tags.map(&:name)

  describe "a new Linear rule" do
    it "tags the Linear tasks already imported from a team it matches, whatever their case" do
      tasks = [linear("acme", "eng-12"), linear("Acme", "ENG-7"), linear("acme", "ops-3"), linear("octocat", "eng-1")]
      save({ pattern: "acme/ENG", provider: "linear", tags: "ruby" })

      expect(tasks.map { tag_names(it) }).to eq([%w[ruby], %w[ruby], [], []])
    end

    it "tags every team in a workspace it names with a star" do
      tasks = [linear("acme", "eng-12"), linear("acme", "ops-3"), linear("octocat", "eng-1")]
      save({ pattern: "acme/*", provider: "linear", tags: "ruby" })

      expect(tasks.map { tag_names(it) }).to eq([%w[ruby], %w[ruby], []])
    end

    it "tags no GitHub task from the same owner" do
      task = sourced("https://github.com/acme/eng/issues/1", provider: "github")
      save({ pattern: "acme/*", provider: "linear", tags: "ruby" })

      expect(tag_names(task)).to be_empty
    end

    it "stands beside a GitHub rule with the same pattern" do
      results = %w[github linear].map { save({ pattern: "acme/*", provider: it, tags: "ruby" }) }

      expect(results.map { it.value!.provider }).to eq(%w[github linear])
    end

    it "refuses a pattern another Linear rule holds" do
      save({ pattern: "acme/*", provider: "linear", tags: "ruby" })

      expect(save({ pattern: "acme/*", provider: "linear", tags: "go" }).failure)
        .to eq([:invalid, { pattern: ["taken"] }])
    end

    it "refuses a provider it does not know" do
      refused = save({ pattern: "acme/*", provider: "jira", tags: "ruby" })

      expect(refused.failure).to match([:invalid, include(:provider)])
    end
  end

  describe "a rule saved with no provider" do
    it "is a GitHub rule" do
      expect(save({ pattern: "acme/*", tags: "ruby" }).value!.provider).to eq("github")
    end

    it "keeps its provider when edited" do
      saved = save({ pattern: "acme/*", provider: "linear", tags: "ruby" }).value!

      expect(save({ pattern: "acme/eng", tags: "go" }, id: saved.id).value!.provider).to eq("linear")
    end
  end

  describe "editing or deleting a Linear rule" do
    let(:saved) { save({ pattern: "octocat/*", provider: "linear", tags: "ruby" }).value! }

    it "tags no task when edited to match it" do
      task = linear("acme", "eng-12")
      save({ pattern: "acme/*", tags: "go" }, id: saved.id)

      expect(tag_names(task)).to be_empty
    end

    it "leaves the tags it gave when deleted" do
      task = linear("octocat", "eng-1")
      saved
      Tasks::Slice["operations.delete_task_tag_rule"].call(saved.id)

      expect(tag_names(task)).to eq(%w[ruby])
    end
  end
end
