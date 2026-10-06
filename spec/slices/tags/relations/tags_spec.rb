# frozen_string_literal: true

RSpec.describe Tags::Relations::Tags do
  let(:tag_repo) { Tags::Slice["repos.tag_repo"] }

  it "refuses to delete the only tag on a task tag rule" do
    Tasks::Slice["operations.save_task_tag_rule"].call({ pattern: "aaronmallen/*", tags: "ruby" }).value!
    ruby = tag_repo.all_in("private").find { it.name == "ruby" }

    expect { tag_repo.delete(ruby.id) }.to raise_error(ROM::SQL::CheckConstraintError, /task_tag_rules_last_tag/)
  end
end
