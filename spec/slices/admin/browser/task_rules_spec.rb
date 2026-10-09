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

  describe "the projects field" do
    let(:capture) { find(".rule-capture") }

    def chips(scope = capture) = scope.all(".project-pick-chip").map { it.text.split.join(" ") }

    def results = capture.all(".project-pick-result").map { it.text.split.join(" ") }

    def search(text, scope = capture) = scope.find("[role='combobox']").send_keys(text)

    before do
      create(:project, :archived, name: "Atlas")
      create(:project, name: "Bloom")
      visit "/admin/tasks/rules"
    end

    it "shows a search box in place of the checkboxes", :aggregate_failures do
      expect(capture).to have_css("[role='combobox']")
      expect(capture).to have_no_css(".rule-projects", visible: :visible)
    end

    it "lists the projects whose names match" do
      search "blo"

      expect(results).to eq(%w[Blog Bloom])
    end

    it "labels archived projects in the list" do
      search "atl"

      expect(results).to eq(["Atlas archived"])
    end

    it "adds a chip for the project picked from the keyboard" do
      search ["bloo", :down, :enter]

      expect(chips).to eq(["Bloom"])
    end

    it "labels an archived project's chip" do
      search "atl"
      capture.find(".project-pick-result", text: "Atlas").click

      expect(chips).to eq(["Atlas archived"])
    end

    it "drops a project when its chip is removed" do
      search ["blog", :down, :enter]
      capture.find("button[aria-label='Remove Blog']").click

      expect(chips).to be_empty
    end

    it "saves the projects picked" do
      fill_in "rule-pattern", with: "octocat/*"
      search ["blog", :down, :enter]
      search ["atl", :down, :enter]
      click_button "Add rule"

      expect(find(".rule-row", text: "octocat/*").all(".rule-project").map(&:text)).to eq(%w[Atlas Blog])
    end

    it "keeps the chips picked when the save fails" do
      search ["blog", :down, :enter]
      click_button "Add rule"

      expect(chips(find(".rule-capture"))).to eq(["Blog"])
    end

    it "opens a rule's editor with chips for its projects" do
      fill_in "rule-pattern", with: "octocat/*"
      search ["bloom", :down, :enter]
      click_button "Add rule"
      find(".rule-row", text: "octocat/*").find(".rule-pattern").click

      expect(chips(editor)).to eq(["Bloom"])
    end
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
    message = confirm_no { editor.click_button "Delete" }

    expect(message)
      .to eq(translate("ui.components.task_rules.row.confirm_delete", pattern: "aaronmallen/*", provider: "GitHub"))
  end

  it "keeps the rule when I don't confirm" do
    row.find(".rule-pattern").click
    confirm_no { editor.click_button "Delete" }

    expect(rules.size).to eq(1)
  end

  it "deletes once I confirm" do
    row.find(".rule-pattern").click
    confirm_yes { editor.click_button "Delete" }

    expect(page).to have_css(".empty")
  end
end
