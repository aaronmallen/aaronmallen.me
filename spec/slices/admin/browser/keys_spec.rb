# frozen_string_literal: true

RSpec.describe "Admin keys", type: :feature do
  def focused = evaluate_script("document.activeElement.textContent.trim()")

  def focused_row = evaluate_script("document.activeElement.closest('[data-key-row]')?.textContent")

  def press(*keys) = page.driver.browser.keyboard.type(*keys)

  def titles = page.all(".li-title").map(&:text)

  before { sign_in_to_admin }

  describe "moving through a list" do
    before do
      create(:post, title: "Alpha")
      create(:post, title: "Beta")
      create(:post, title: "Gamma")
      visit "/admin/posts"
    end

    it "highlights the first row on j" do
      press("j")

      expect(focused).to eq(titles.first)
    end

    it "moves down on each j" do
      press("j", "j")

      expect(focused).to eq(titles[1])
    end

    it "moves back up on k" do
      press("j", "j", "k")

      expect(focused).to eq(titles.first)
    end

    it "stops at the last row" do
      press(*Array.new(5, "j"))

      expect(focused).to eq(titles.last)
    end

    it "starts from the last row on k" do
      press("k")

      expect(focused).to eq(titles.last)
    end

    it "marks the highlighted row" do
      press("j")

      expect(page).to have_css("[data-key-row]:has(:focus-visible)", text: titles.first)
    end
  end

  describe "opening the highlighted row" do
    let!(:post) { create(:post, title: "Only post") }

    before do
      visit "/admin/posts"
      press("j", :enter)
    end

    it "goes where a click on it goes" do
      expect(page).to have_current_path("/admin/posts/#{post.id}/edit")
    end
  end

  describe "a long list" do
    before do
      30.times { create(:task, title: "Chore #{it}") }
      visit "/admin/tasks?filter=next"
      press("k")
    end

    it "scrolls the highlighted row into view" do
      bottom = evaluate_script("document.activeElement.closest('[data-key-row]').getBoundingClientRect().bottom")

      expect(bottom).to be <= evaluate_script("window.innerHeight")
    end
  end

  describe "a task list" do
    before do
      create(:task, title: "Write the brief")
      visit "/admin/tasks?filter=next"
      press("j", :enter)
    end

    it "opens the task the way a click does" do
      expect(page).to have_css("dialog[data-task-panel][open]", text: "Write the brief")
    end
  end

  describe "task row keys" do
    let(:repo) { Tasks::Slice["repos.task_repo"] }

    def task(title) = repo.all_open.find { it.title == title }

    before do
      create(:task, title: "Write the brief")
      create(:task, title: "Book the venue")
      visit "/admin/tasks?filter=next"
    end

    describe "s" do
      let!(:rows) { page.all(".task-title").map(&:text) }

      before do
        press("j", "j", "s")
        find(".toast")
      end

      it "starts the highlighted task" do
        expect(task(rows.last)).to have_attributes(status: "in_progress")
      end

      it "leaves the other task alone" do
        expect(task(rows.first)).to have_attributes(status: "open")
      end
    end

    describe "m" do
      before { press("j", "m") }

      it "moves the task the way its first arrow does" do
        expect(page).to have_current_path("/admin/tasks?filter=today")
      end
    end

    describe "e" do
      before { press("j", "e") }

      it "opens the task for editing the way the pen does" do
        expect(page).to have_css("dialog[open] [data-task-edit] form.task-form")
      end
    end

    describe "with no highlight" do
      before { press("s") }

      it "starts nothing", :aggregate_failures do
        expect(page).to have_current_path("/admin/tasks?filter=next")
        expect(repo.all_open.map(&:status)).to all(eq("open"))
      end
    end
  end

  describe "x" do
    let(:sprint) { create(:sprint, sprint_date: Blog::TimeZone.today) }

    def done = Admin::Slice["i18n"].t("ui.components.tasks.controls.complete")

    before do
      create(:task, :in_progress, :in_sprint, sprint_id: sprint.id, title: "Ship the screen")
      visit "/admin/tasks?filter=today"
      press("j", "x")
    end

    it "opens the done panel the way a click does" do
      expect(page).to have_css("details.task-complete[open]")
    end

    it "moves focus to the done button" do
      expect(focused).to eq(done)
    end

    it "completes the task from there" do
      find("details.task-complete[open]").click_button(done)

      expect(Tasks::Slice["repos.task_repo"].all_open).to be_empty
    end
  end

  describe "the help overlay on a task list" do
    def help = find_by_id("key-help")

    before do
      sprint = create(:sprint, sprint_date: Blog::TimeZone.today)
      create(:task, :in_progress, :in_sprint, sprint_id: sprint.id, title: "Ship the screen")
      create(:task, :in_sprint, sprint_id: sprint.id, title: "Write the brief")
      visit "/admin/tasks?filter=today"
      press("?")
    end

    it "lists the task row keys", :aggregate_failures do
      expect(help).to have_css(".keys-row", text: /\Ax\s+Complete the highlighted task\z/)
      expect(help).to have_css(".keys-row", text: /\As\s+Start the highlighted task\z/)
      expect(help).to have_css(".keys-row", text: /\Am\s+Move the highlighted task one list over\z/)
      expect(help).to have_css(".keys-row", text: /\Ae\s+Edit the highlighted task\z/)
    end
  end

  describe "p on the posts list" do
    let(:repo) { Posts::Slice["repos.post_repo"] }
    let!(:draft) { create(:post, :draft, title: "Half done") }
    let!(:published) { create(:post, :published, title: "Out already") }

    def row_of(post) = titles.index(post.title) + 1

    def status(post) = repo.by_id(post.id).status

    before { visit "/admin/posts" }

    it "publishes the highlighted draft" do
      press(*Array.new(row_of(draft), "j"), "p")
      find(".toast", text: "Published")

      expect(status(draft)).to eq("published")
    end

    it "does nothing on a published post", :aggregate_failures do
      published_at = repo.by_id(published.id).published_at
      press(*Array.new(row_of(published), "j"), "p")

      expect(page).to have_current_path("/admin/posts")
      expect(repo.by_id(published.id).published_at).to eq(published_at)
      expect(status(draft)).to eq("draft")
    end

    it "does nothing with no highlight", :aggregate_failures do
      press("p")

      expect(page).to have_current_path("/admin/posts")
      expect(status(draft)).to eq("draft")
    end

    it "lists p in the help overlay" do
      press("?")

      expect(find_by_id("key-help")).to have_css(".keys-row", text: /\Ap\s+Publish the highlighted draft\z/)
    end
  end

  describe "r on the messages list" do
    let(:repo) { Contact::Slice["repos.message_repo"] }
    let!(:first) { create(:message, subject: "First", received_at: Time.now) }
    let!(:second) { create(:message, subject: "Second", received_at: Time.now - 60) }

    before { visit "/admin/messages" }

    it "marks the highlighted message read", :aggregate_failures do
      press("j", "r")
      find(".toast", text: "Marked read")

      expect(repo.by_id(first.id).status).to eq("read")
      expect(repo.by_id(second.id).status).to eq("unread")
    end

    it "does nothing with no highlight" do
      press("r")

      expect(repo.by_id(first.id).status).to eq("unread")
    end

    it "lists r in the help overlay" do
      press("?")

      expect(find_by_id("key-help")).to have_css(".keys-row", text: /\Ar\s+Mark the highlighted message read\z/)
    end
  end

  describe "g jumps" do
    before { visit "/admin/analytics" }

    {
      "t" => "/admin", "k" => "/admin/tasks", "j" => "/admin/journal", "p" => "/admin/posts",
      "a" => "/admin/activity",
    }.each do |letter, path|
      it "goes to #{path} on g #{letter}" do
        press("g", letter)

        expect(page).to have_current_path(path)
      end
    end

    it "does nothing on g alone", :aggregate_failures do
      press("g")
      find(".ctx-btn[aria-label='Show the keys']").click

      expect(page).to have_css("dialog#key-help[open]")
      expect(page).to have_current_path("/admin/analytics")
    end

    it "does nothing on a letter with no section", :aggregate_failures do
      press("g", "x", "t")
      press("?")

      expect(page).to have_css("dialog#key-help[open]")
      expect(page).to have_current_path("/admin/analytics")
    end

    it "lists the jumps in the help overlay", :aggregate_failures do
      press("?")

      expect(find_by_id("key-help")).to have_css(".keys-row", text: /\Ag\s*t\s+Go to today\z/)
      expect(find_by_id("key-help")).to have_css(".keys-row", text: /\Ag\s*a\s+Go to activity\z/)
    end
  end

  describe "c" do
    def task_dialog = "dialog##{Admin::UI::Components::Tasks::CreateDialog::ID}[open]"

    {
      "/admin/posts" => "/admin/posts/new", "/admin/projects" => "/admin/projects/new",
      "/admin/decisions" => "/admin/decisions/new", "/admin/people" => "/admin/people/new",
    }.each do |screen, form|
      it "opens #{form} from #{screen}" do
        visit screen
        press("c")

        expect(page).to have_current_path(form)
      end
    end

    ["/admin", "/admin/tasks"].each do |screen|
      it "opens the task dialog on #{screen}" do
        visit screen
        press("c")

        expect(page).to have_css(task_dialog)
      end
    end

    it "does nothing on a screen with no create button", :aggregate_failures do
      visit "/admin/analytics"
      press("c")
      press("?")

      expect(page).to have_css("dialog#key-help[open]")
      expect(page).to have_current_path("/admin/analytics")
    end

    it "lists c in the help overlay where it works" do
      visit "/admin/posts"
      press("?")

      expect(find_by_id("key-help")).to have_css(".keys-row", text: /\Ac\s+New post\z/)
    end

    it "leaves c out of the help overlay where it does nothing" do
      visit "/admin/analytics"
      press("?")

      expect(find_by_id("key-help")).to have_no_css(".keys-row", text: /\Ac\s/)
    end
  end

  describe "a row with no link" do
    before do
      create(:message, subject: "Hello there")
      visit "/admin/messages"
      press("j")
    end

    it "highlights the row itself" do
      expect(evaluate_script("document.activeElement.matches('[data-key-row]')")).to be(true)
    end

    it "holds the message" do
      expect(focused_row).to include("Hello there")
    end
  end

  describe "the help overlay" do
    def help = find_by_id("key-help")

    before do
      create(:task, title: "Write the brief")
      visit "/admin/tasks?filter=next"
    end

    it "stays shut until something opens it" do
      expect(page).to have_no_css("dialog#key-help[open]")
    end

    describe "opening it with ?" do
      before { press("?") }

      it "opens the overlay" do
        expect(page).to have_css("dialog#key-help[open]")
      end

      it "lists the list keys", :aggregate_failures do
        expect(help).to have_css(".keys-row", text: "Highlight the next row")
        expect(help).to have_css(".keys-row", text: "Highlight the row above")
        expect(help).to have_css(".keys-row", text: "Open the highlighted row")
      end

      it "lists the keys the screen's controls carry", :aggregate_failures do
        expect(help).to have_css(".keys-row", text: %r{\A/\s+Open the command palette\z})
        expect(help).to have_css(".keys-row", text: /\A\?\s+Show the keys\z/)
      end

      it "lists the reorder keys on a task list" do
        expect(help).to have_css(".keys-row", text: "Move the focused task up or down")
      end

      it "lists each key once" do
        press("?")

        expect(help).to have_css(".keys-row", text: "Show the keys", count: 1)
      end

      it "keeps the list keys quiet behind it" do
        press("j")

        expect(focused_row).to be_nil
      end

      it "shuts on Escape" do
        help.send_keys(:escape)

        expect(page).to have_no_css("dialog#key-help[open]")
      end
    end

    describe "opening it from the button" do
      before { find(".ctx-btn[aria-label='Show the keys']").click }

      it "opens the overlay" do
        expect(page).to have_css("dialog#key-help[open]")
      end
    end

    describe "on a screen with no list" do
      before do
        visit "/admin/analytics"
        press("?")
      end

      it "leaves out the list keys" do
        expect(help).to have_no_css(".keys-row", text: "Highlight the next row")
      end

      it "leaves out the reorder keys" do
        expect(help).to have_no_css(".keys-row", text: "Move the focused task up or down")
      end
    end
  end

  describe "typing in a field" do
    before do
      create(:tag, name: "ruby")
      visit "/admin/tags"
      find_by_id("tags-q").send_keys("j", "k", "?")
    end

    it "keeps the keys in the field" do
      expect(page).to have_field("tags-q", with: "jk?")
    end

    it "moves no highlight" do
      expect(focused_row).to be_nil
    end

    it "leaves the help shut" do
      expect(page).to have_no_css("dialog#key-help[open]")
    end
  end
end
