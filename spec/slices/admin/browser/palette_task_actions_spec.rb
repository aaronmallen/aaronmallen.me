# frozen_string_literal: true

RSpec.describe "Admin palette task actions", type: :feature do
  let(:repo) { Tasks::Slice["repos.task_queries"] }

  def in_progress(title) = create(:task, :in_progress, :in_sprint, title:)

  def open_palette = page.driver.browser.keyboard.type([:meta, "/"])

  def open_sessions(task) = Tasks::Slice["relations.work_sessions"].running.for_task(task.id).to_a

  def query = find("[data-palette-query]")

  def status(task) = repo.by_id(task.id).status

  before { sign_in_to_admin }

  describe "on a task that is not in progress" do
    let!(:task) { create(:task, title: "Email the accountant") }

    before do
      visit "/admin/tasks/#{task.id}?filter=next"
      open_palette
      query.send_keys(*"task".chars)
    end

    it "offers Start task and not Complete task or Pause task", :aggregate_failures do
      expect(page).to have_css("#command-palette-start-task", text: "Start task")
      expect(page).to have_no_css("#command-palette-complete-task, [id^='command-palette-pause-task']")
    end

    describe "running Start task" do
      before do
        query.send_keys(*Array.new(4, :backspace), *"start task".chars, :enter)
        page.assert_selector("[data-toast]", text: "Started")
      end

      it "starts it" do
        expect(status(task)).to eq("in_progress")
      end

      it "leaves me on the task, shown in progress", :aggregate_failures do
        expect(page).to have_current_path("/admin/tasks/#{task.id}?filter=next")
        expect(page).to have_css(".read-meta", text: "in progress")
      end
    end
  end

  describe "on a task in progress" do
    let!(:task) { in_progress("Ship the palette") }

    before do
      visit "/admin/tasks/#{task.id}?filter=today"
      open_palette
      query.send_keys(*"task".chars)
    end

    it "offers Complete task and Pause task and not Start task", :aggregate_failures do
      expect(page).to have_css("#command-palette-complete-task", text: "Complete task")
      expect(page).to have_css("#command-palette-pause-task", text: "Pause task")
      expect(page).to have_no_css("#command-palette-start-task")
    end

    it "lists no other task in progress" do
      expect(page).to have_no_css("[id*='-task-in-progress-']")
    end

    describe "running Pause task" do
      before do
        query.send_keys(*Array.new(4, :backspace), *"pause task".chars, :enter)
        page.assert_selector("[data-toast]", text: "Stopped")
      end

      it "returns it to open and ends its work session", :aggregate_failures do
        expect(status(task)).to eq("open")
        expect(open_sessions(task)).to be_empty
      end

      it "leaves me on the task, shown open", :aggregate_failures do
        expect(page).to have_current_path("/admin/tasks/#{task.id}?filter=today")
        expect(page).to have_css(".read-meta", text: "open")
      end
    end

    describe "running Complete task" do
      before do
        query.send_keys(*Array.new(4, :backspace), *"complete task".chars, :enter)
        page.assert_selector("[data-toast]", text: "Done")
      end

      it "completes it" do
        expect(status(task)).to eq("done")
      end

      it "leaves me on the task, shown done", :aggregate_failures do
        expect(page).to have_current_path("/admin/tasks/#{task.id}?filter=today")
        expect(page).to have_css(".read-meta", text: "done")
      end
    end
  end

  describe "on a closed task" do
    before do
      in_progress("Ship the palette")
      visit "/admin/tasks/#{create(:task, :done).id}"
      open_palette
      query.send_keys(*"task".chars)
      page.assert_selector("#command-palette-create-task")
    end

    it "offers none of them, nor the tasks in progress", :aggregate_failures do
      expect(page).to have_no_css("#command-palette-start-task")
      expect(page).to have_no_css("[id^='command-palette-complete-task'], [id^='command-palette-pause-task']")
    end
  end

  describe "with tasks in progress and no task on screen" do
    let!(:first) { in_progress("Ship the palette") }

    before do
      in_progress("Write the record")
      create(:task, title: "Not started")
      visit "/admin/posts"
      open_palette
      query.send_keys(*"complete".chars)
    end

    it "lists each task in progress by title", :aggregate_failures do
      expect(page).to have_css(".pal-r", text: "Complete Ship the palette")
      expect(page).to have_css(".pal-r", text: "Complete Write the record")
      expect(page).to have_no_css(".pal-r", text: "Not started")
    end

    it "offers no Start task or Complete task" do
      expect(page).to have_no_css("#command-palette-start-task, #command-palette-complete-task")
    end

    describe "running one" do
      before do
        find_by_id("command-palette-complete-task-in-progress-#{first.id}").click
        page.assert_selector("[data-toast]", text: "Done")
      end

      it "completes that task" do
        expect(status(first)).to eq("done")
      end

      it "leaves me on the screen I ran it from" do
        expect(page).to have_current_path("/admin/posts")
      end
    end
  end

  describe "pausing with tasks in progress and no task on screen" do
    let!(:first) { in_progress("Ship the palette") }

    before do
      in_progress("Write the record")
      create(:task, title: "Not started")
      visit "/admin/posts"
      open_palette
      query.send_keys(*"pause".chars)
    end

    it "lists each task in progress by title", :aggregate_failures do
      expect(page).to have_css(".pal-r", text: "Pause Ship the palette")
      expect(page).to have_css(".pal-r", text: "Pause Write the record")
      expect(page).to have_no_css(".pal-r", text: "Not started")
    end

    it "offers no Pause task" do
      expect(page).to have_no_css("#command-palette-pause-task")
    end

    describe "running one" do
      before do
        find_by_id("command-palette-pause-task-in-progress-#{first.id}").click
        page.assert_selector("[data-toast]", text: "Stopped")
      end

      it "returns that task to open and ends its work session", :aggregate_failures do
        expect(status(first)).to eq("open")
        expect(open_sessions(first)).to be_empty
      end

      it "leaves me on the screen I ran it from" do
        expect(page).to have_current_path("/admin/posts")
      end
    end
  end

  describe "with no task on screen and none in progress" do
    before do
      create(:task, title: "Not started")
      visit "/admin/posts"
      open_palette
      query.send_keys(*"complete".chars)
      page.driver.wait_for_network_idle
    end

    it "lists none" do
      expect(page).to have_no_css("[id^='command-palette-complete-task'], [id^='command-palette-pause-task']")
    end

    it "lists none to pause" do
      query.send_keys(*Array.new(8, :backspace), *"pause".chars)

      expect(page).to have_no_css("[id^='command-palette-pause-task']")
    end
  end

  describe "on a task open in the flyout" do
    let!(:task) { create(:task, title: "Email the accountant") }

    before do
      in_progress("Ship the palette")
      visit "/admin/tasks?filter=next"
      click_link("Email the accountant")
      page.assert_selector("dialog[data-task-panel][open]", text: "Email the accountant")
      open_palette
      query.send_keys(*"task".chars)
    end

    it "acts on the task in the flyout", :aggregate_failures do
      expect(page).to have_css("#command-palette-start-task")
      expect(page).to have_no_css("[id^='command-palette-complete-task']")
    end

    describe "running Start task" do
      before do
        find_by_id("command-palette-start-task").click
        page.assert_selector("[data-toast]", text: "Started")
      end

      it "starts it" do
        expect(status(task)).to eq("in_progress")
      end

      it "leaves me on the list I ran it from" do
        expect(page).to have_current_path("/admin/tasks?filter=next")
      end
    end
  end

  describe "on a phone" do
    let!(:task) { create(:task, title: "Email the accountant") }

    before do
      page.driver.resize(375, 800)
      visit "/admin/tasks/#{task.id}"
      click_button(class: "top-bar-search")
      find_by_id("command-palette-start-task").click
      page.assert_selector("[data-toast]", text: "Started")
    end

    it "starts the task from the slash button", :aggregate_failures do
      expect(status(task)).to eq("in_progress")
      expect(page).to have_current_path("/admin/tasks/#{task.id}")
    end

    describe "then pausing it" do
      before do
        click_button(class: "top-bar-search")
        find_by_id("command-palette-pause-task").click
        page.assert_selector("[data-toast]", text: "Stopped")
      end

      it "returns it to open" do
        expect(status(task)).to eq("open")
      end
    end

    describe "then completing it" do
      before do
        click_button(class: "top-bar-search")
        find_by_id("command-palette-complete-task").click
        page.assert_selector("[data-toast]", text: "Done")
      end

      it "completes it" do
        expect(status(task)).to eq("done")
      end
    end
  end
end
