# frozen_string_literal: true

RSpec.describe "Admin inbox", type: :feature do
  context "when editing an issue" do
    let(:repo) { Tasks::Slice["repos.task_repo"] }
    let(:task) { create(:task, :external, title: "Fix the feed") }

    def modal = find("dialog#task-create[open]")

    def save(**fields)
      within(".li", text: "Fix the feed") { click_link("Edit") }
      modal.assert_selector("[data-task-edit]")
      expect(page).to have_current_path("/admin/inbox")
      fields.each { |name, value| modal.fill_in("task[#{name}]", with: value) }
      modal.click_button("Save")
    end

    before do
      create(:task_source, task:)
      sign_in_to_admin
      visit "/admin/inbox"
    end

    it "saves a tag change in the dialog, stays on the inbox and drops the issue", :aggregate_failures do
      save(tags: "feeds")

      expect(page).to have_css("[data-toast]", text: "Task saved")
      expect(page).to have_current_path("/admin/inbox")
      expect(page).to have_no_css(".li", text: "Fix the feed")
      expect(repo.by_id(task.id).tags.map(&:name)).to eq(["feeds"])
    end

    it "keeps the issue when the dialog saves only a note", :aggregate_failures do
      save(note: "Look at the cache")

      expect(page).to have_current_path("/admin/inbox")
      expect(page).to have_css(".li", text: "Fix the feed")
    end
  end

  context "with a long title" do
    let(:title) { "A synced issue with a title long enough to wrap onto a second line beside its buttons " * 2 }

    def box(selector)
      evaluate_script(<<~JS, find(selector))
        (r => ({ left: r.left, right: r.right, top: r.top, bottom: r.bottom }))(arguments[0].getBoundingClientRect())
      JS
    end

    before do
      create(:task, title:, list: "external").tap { create(:task_source, task: it) }
      sign_in_to_admin
      visit "/admin/inbox"
    end

    it "keeps the buttons to the right of a long title", :aggregate_failures do
      title_box = box(".li .li-main")
      side_box = box(".li .li-side")

      expect(side_box["left"]).to be >= title_box["right"]
      expect(side_box["top"]).to be < title_box["bottom"]
    end

    it "stacks the buttons below the title on a phone" do
      page.driver.resize(375, 800)

      expect(box(".li .li-side")["top"]).to be >= box(".li .li-main")["bottom"]
    end
  end
end
