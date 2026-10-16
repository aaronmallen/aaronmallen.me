# frozen_string_literal: true

RSpec.describe "Admin tag field", type: :feature do
  let(:posts) { Posts::Slice["repos.post_queries"] }
  let(:projects) { Projects::Slice["repos.project_queries"] }
  let(:project) { create(:project, name: "sai", tags: %w[ruby]) }

  def chips = all(".tag-pick-chip").map { it.text.strip }

  def field = find("[data-tag-field-input]")

  def results = all(".tag-pick-result").map(&:text)

  def save_project
    click_button "Save project"
    page.assert_selector("[data-toast]", text: "Project saved")
  end

  def saved_tags = projects.by_id(project.id).tags.map(&:name)

  before do
    create(:tag, name: "ruby", color: "mk-green")
    create(:tag, name: "rails", color: "mk-pink")
    create(:tag, :private, name: "rake")
    sign_in_to_admin
    visit "/admin/projects/#{project.id}/edit"
  end

  it "shows the tags as chips in place of the comma box", :aggregate_failures do
    expect(page).to have_no_field("project[tags]")
    expect(chips).to eq(["#ruby"])
  end

  it "lists the public tags that match, each in its color", :aggregate_failures do
    field.send_keys("ra")

    expect(results).to eq(["#rails", "New tag ra"])
    expect(page).to have_css(".tag-pick-result .tag.pink", text: "#rails")
  end

  it "picks a suggestion by keyboard alone and adds a chip in its color", :aggregate_failures do
    field.send_keys("rai", :down, :enter)

    expect(chips).to eq(["#ruby", "#rails"])
    expect(page).to have_css(".tag-pick-chip .tag.pink", text: "#rails")
  end

  it "closes the suggestions on Escape" do
    field.send_keys("ra")
    field.send_keys(:escape)

    expect(page).to have_no_css(".tag-pick-result")
  end

  it "saves a picked tag" do
    field.send_keys("rai", :down, :enter)
    save_project

    expect(saved_tags).to eq(%w[rails ruby])
  end

  it "takes a removed chip's tag off on save" do
    find("button[aria-label='Remove ruby']").click
    save_project

    expect(saved_tags).to eq([])
  end

  it "adds a chip for a new name and creates the tag on save", :aggregate_failures do
    field.send_keys("hanami", :enter)

    expect(chips).to eq(["#ruby", "#hanami"])
    save_project
    expect(saved_tags).to eq(%w[hanami ruby])
  end

  it "binds once after a morph" do
    execute_script(<<~JS)
      const main = document.querySelector("main");
      main.outerHTML = main.outerHTML;
      document.dispatchEvent(new Event("admin:morphed"));
      document.dispatchEvent(new Event("admin:morphed"));
    JS
    field.send_keys("r", :down)

    expect(page).to have_css(".tag-pick-result[aria-selected='true']", exact_text: "#rails")
  end

  it "suggests public tags in the post details" do
    visit "/admin/posts/#{create(:post, :draft).id}/edit"
    click_button "Details"
    find("dialog#post-details[open] [data-tag-field-input]").send_keys("r")

    expect(results).to eq(["#rails", "#ruby", "New tag r"])
  end

  describe "on the private forms" do
    let(:tasks) { Tasks::Slice["repos.task_queries"] }

    def open_drawer_editor(task)
      visit "/admin/tasks?filter=next"
      find(".task-title", text: task.title).click
      find("dialog#task-panel[open]").click_link("Edit")
      find("dialog#task-panel[open] [data-task-edit] [data-tag-field-input]")
    end

    before do
      create(:tag, :private, name: "chores", color: "mk-green")
      create(:message).tap { Mail::Slice["repos.message_tag_mutations"].add(it.id, "barn") }
    end

    describe "in the task modal" do
      def modal = find("dialog#task-create[open]")

      def modal_field = modal.find("[data-tag-field-input]")

      before do
        visit "/admin/tasks"
        click_link "Create Task"
      end

      it "lists the private tags that match, each in its color", :aggregate_failures do
        modal_field.send_keys("r")

        expect(results).to eq(["#chores", "#rake", "New tag r"])
        expect(page).to have_css(".tag-pick-result .tag.green", text: "#chores")
      end

      it "saves the pick" do
        modal.fill_in "task[title]", with: "Sweep the porch"
        modal_field.send_keys("cho", :down, :enter)
        modal.click_button "Create task"
        page.assert_selector(".task-title", text: "Sweep the porch")

        expect(tasks.by_tag("chores").map(&:title)).to eq(["Sweep the porch"])
      end
    end

    it "adds and saves a chip in the task drawer" do
      task = create(:task, title: "Mop the floor", tags: %w[rake])
      open_drawer_editor(task).send_keys("cho", :down, :enter)
      find("dialog#task-panel[open]").click_button("Save")
      find("dialog#task-panel[open] [data-task-read]")

      expect(tasks.by_id(task.id).tags.map(&:name)).to eq(%w[chores rake])
    end

    it "binds the drawer's field once after a morph" do
      open_drawer_editor(create(:task, title: "Mop the floor"))
      execute_script('document.dispatchEvent(new Event("admin:morphed"));' * 2)
      find("dialog#task-panel[open] [data-tag-field-input]").send_keys("r", :down)

      expect(page).to have_css(".tag-pick-result[aria-selected='true']", exact_text: "#chores")
    end

    describe "in the journal dialog" do
      def journal_field = find_by_id("journal-write-tags-search")

      def journal_tags = Record::Slice["repos.journal_entry_queries"].today.flat_map { it.tags.map(&:name) }

      before do
        visit "/admin/posts"
        page.driver.browser.keyboard.type("w")
        fill_in "journal-write-body", with: "walked"
      end

      it "lists the private tags that match" do
        journal_field.send_keys("r")

        expect(results).to eq(["#chores", "#rake", "New tag r"])
      end

      it "saves the chips" do
        journal_field.send_keys("cho", :down, :enter, "lake", :enter)
        find("dialog#journal-write").click_button("Save")
        page.assert_selector(".toast", text: "Journal entry saved")

        expect(journal_tags).to eq(%w[chores lake])
      end
    end
  end
end
