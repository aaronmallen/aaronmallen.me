# frozen_string_literal: true

RSpec.describe Tags::Relations::Tags do
  let(:tag_repo) { Tags::Slice["repos.tag_repo"] }

  def ruby = tag_repo.all_in("private").find { it.name == "ruby" }

  def save_rule(**) = Tasks::Slice["operations.save_task_rule"].call({ pattern: "aaronmallen/*", ** }).value!

  it "refuses to delete the only tag on a task rule" do
    save_rule(tags: "ruby")

    expect { tag_repo.delete(ruby.id) }.to raise_error(ROM::SQL::CheckConstraintError, /task_rules_last_target/)
  end

  it "deletes the only tag on a task rule that holds a project" do
    save_rule(tags: "ruby", projects: [create(:project).id])
    tag_repo.delete(ruby.id)

    expect(ruby).to be_nil
  end

  it "names no rule that holds a project beside the tag" do
    save_rule(tags: "ruby", projects: [create(:project).id])

    expect(tag_repo.last_tag_of_rules(ruby.id)).to be_empty
  end

  it "refuses to delete the only project on a task rule with no tags" do
    project = create(:project)
    save_rule(tags: "", projects: [project.id])

    expect { Projects::Slice["relations.projects"].by_pk(project.id).delete }
      .to raise_error(Sequel::CheckConstraintViolation, /would leave a task rule with no tags or projects/)
  end
end
