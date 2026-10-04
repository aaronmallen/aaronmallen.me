# frozen_string_literal: true

RSpec.describe Tags::Relations::Tags do
  let(:rules) { Tasks::Slice["queries.task_tag_rules"] }
  let(:tag_repo) { Tags::Slice["repos.tag_repo"] }

  def named(name) = tag_repo.all_in("private").find { it.name == name }

  def rule(pattern, tags) = Tasks::Slice["operations.save_task_tag_rule"].call({ pattern:, tags: }).value!

  def tags_of(pattern) = rules.call.find { it.pattern == pattern }.tags.map(&:name)

  describe "deleting a tag" do
    it "refuses the only tag on a task tag rule" do
      rule("aaronmallen/*", "ruby")

      expect { tag_repo.delete(named("ruby").id) }
        .to raise_error(ROM::SQL::CheckConstraintError, /task_tag_rules_last_tag/)
    end

    it "takes a tag off a rule that holds another" do
      rule("aaronmallen/*", "ruby, projects")
      tag_repo.delete(named("ruby").id)

      expect(tags_of("aaronmallen/*")).to eq(%w[projects])
    end

    it "deletes a tag once its rule is gone" do
      Tasks::Slice["operations.delete_task_tag_rule"].call(rule("aaronmallen/*", "ruby").id)
      tag_repo.delete(named("ruby").id)

      expect(named("ruby")).to be_nil
    end
  end

  describe "#last_tag_of_rules" do
    it "names each rule the tag is the only tag on, by pattern" do
      rule("rails/*", "ruby")
      rule("aaronmallen/*", "ruby")
      rule("hanami/*", "ruby, hanami")

      expect(tag_repo.last_tag_of_rules(named("ruby").id)).to eq(%w[aaronmallen/* rails/*])
    end
  end
end
