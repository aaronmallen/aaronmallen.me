# frozen_string_literal: true

RSpec.describe "Admin menus for the remaining rows with actions", type: :feature do
  def open_menu(target)
    scroll_to(target, align: :center)
    box = target.evaluate_script("JSON.parse(JSON.stringify(this.getBoundingClientRect()))")
    keep_page
    page.driver.browser.mouse.click(x: box["left"] + 2, y: box["top"] + (box["height"] / 2), button: :right)
    menu
  end

  before { sign_in_to_admin }

  it "opens a menu on a row that is itself a link" do
    create(:commit, commit_date: Blog::TimeZone.today, message: "add the view")
    visit "/admin/activity"
    open_menu(find("a.activity-event", text: "add the view"))

    expect(menu).to have_css(".ctx-item", text: "Copy SHA")
  end

  describe "a task comment" do
    let(:task) { create(:task) }
    let!(:comment) { create(:task_comment, task_id: task.id, body: "First try") }

    before do
      visit "/admin/tasks/#{task.id}"
      open_menu(find("#task-comment-#{comment.id} .comment-head"))
    end

    it "opens its edit form in place from Edit", :aggregate_failures do
      item("Edit").click

      expect(page).to have_css("#task-comment-#{comment.id} details.comment-edit[open]")
      expect(kept_page?).to be(true)
    end
  end

  it "opens a task rule's editor from Edit" do
    rule = Tasks::Slice["operations.save_task_rule"].call({ pattern: "aaronmallen/*", tags: "ruby" }).value!
    visit "/admin/settings/tagging"
    open_menu(find(".rule-row .rule-provider"))
    item("Edit").click

    expect(find("#rule-#{rule.id}-edit", visible: :all)).to be_checked
  end

  describe "a token" do
    before do
      API::Slice["operations.mint_token"].call(name: "Terminal")
      visit "/admin/tokens"
      open_menu(find(".li .li-title", text: "Terminal"))
    end

    it "revokes it in place on the second click", :aggregate_failures do
      item("Revoke").click
      item("Click again to revoke").click

      expect(page).to have_css(".toast", text: "Token revoked")
      expect(page).to have_no_css(".li-title", text: "Terminal")
      expect(kept_page?).to be(true)
    end
  end
end
