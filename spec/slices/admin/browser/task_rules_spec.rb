# frozen_string_literal: true

RSpec.describe "Admin task rules", type: :feature do
  let(:row) { find(".rule-row", text: "aaronmallen/*") }

  def editor = find(".rule-editor", visible: :visible)

  def rules = Tasks::Slice["repos.task_rule_queries"].all

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  before do
    Tasks::Slice["operations.save_task_rule"].call({ pattern: "aaronmallen/*", tags: "projects" })
    create(:project, name: "Blog")
    sign_in_to_admin
    visit "/admin/tasks/rules"
  end

  it "adds a rule" do
    fill_in "rule-pattern", with: "aaronmallen/aaronmallen.me"
    fill_in "rule-tags", with: "ruby"
    click_button "Add rule"

    expect(page).to have_css(".rule-pattern", text: "aaronmallen/aaronmallen.me")
  end

  it "adds a rule that gives only a project" do
    fill_in "rule-pattern", with: "octocat/*"
    within(".rule-capture") { check "Blog" }
    click_button "Add rule"

    expect(find(".rule-row", text: "octocat/*")).to have_css(".rule-project", text: "Blog")
  end

  it "keeps the editor shut until the rule is clicked" do
    expect(page).to have_no_css(".rule-editor", visible: :visible)
  end

  it "edits a rule's tags" do
    row.find(".rule-pattern").click
    editor.fill_in("rule[tags]", with: "projects, ruby")
    editor.click_on("Save")

    expect(page).to have_css(".rule-tags .tag", text: "#ruby")
  end

  it "asks with the confirmation text before it deletes" do
    row.find(".rule-pattern").click
    message = dismiss_confirm { editor.click_button "Delete" }

    expect(message)
      .to eq(translate("ui.components.task_rules.row.confirm_delete", pattern: "aaronmallen/*", provider: "GitHub"))
  end

  it "keeps the rule when I don't confirm" do
    row.find(".rule-pattern").click
    dismiss_confirm { editor.click_button "Delete" }

    expect(rules.size).to eq(1)
  end

  it "deletes once I confirm" do
    row.find(".rule-pattern").click
    accept_confirm { editor.click_button "Delete" }

    expect(page).to have_css(".empty")
  end
end
