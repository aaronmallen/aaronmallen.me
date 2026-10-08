# frozen_string_literal: true

RSpec.describe "Admin command palette", type: :feature do
  def active = evaluate_script("document.querySelector('[data-palette-option][aria-selected=\"true\"]').id")

  def open_palette = find("body").send_keys([:meta, "/"])

  def query = find("[data-palette-query]")

  def search_path = "/admin/search/palette"

  before do
    create(:task, title: "Email the accountant")
    create(:message)
    sign_in_to_admin
    visit "/admin"
  end

  it "stays shut until something opens it" do
    expect(page).to have_no_css("dialog#command-palette[open]")
  end

  it "says where you are on every screen", :aggregate_failures do
    visit "/admin/posts"

    expect(page).to have_css(".pill-nav-link[aria-current='page']", text: "Publish")
    expect(page).to have_css(".screen-tab[aria-current='page']", text: "posts")
  end

  it "flags the unread message on the inbox pill" do
    expect(page).to have_css(".pill-nav-link[href='/admin/inbox'] .pill-nav-dot")
  end

  describe "opening it with the keyboard" do
    before { open_palette }

    it "opens the dialog" do
      expect(page).to have_css("dialog#command-palette[open]")
    end

    it "puts the cursor in the query box" do
      expect(evaluate_script("document.activeElement.getAttribute('role')")).to eq("combobox")
    end

    it "rings the query box" do
      expect(evaluate_script(<<~JS)).to be(true)
        (s => s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) > 0)(getComputedStyle(document.activeElement))
      JS
    end

    it "makes the query box tall enough to tap" do
      expect(evaluate_script("document.activeElement.getBoundingClientRect().height")).to be >= 44
    end

    it "lists every section and settings tab under Go to", :aggregate_failures do
      within("[aria-labelledby='command-palette-group-go-to']") do
        expect(page).to have_css(".pal-g", text: /go to/i)
        expect(page).to have_css("#command-palette-messages")
        expect(page).to have_css("#command-palette-security")
      end
    end

    it "orders the groups Actions, Saved views, Go to, Records, Search" do
      groups = page.all("#command-palette [data-palette-group]", visible: :all).map { it["aria-labelledby"] }
      names = groups.map { it.sub(/\Acommand-palette-(group-)?/, "").sub(/\Akind-.+/, "records") }

      expect(names.uniq).to eq(%w[actions saved-views go-to records see-all])
    end

    it "shows the key on the actions that have one", :aggregate_failures do
      expect(page).to have_css("#command-palette-create-task .pal-r-key", text: "c")
      expect(page).to have_css("#command-palette-create-journal-entry .pal-r-key", text: "w")
    end

    it "selects the first row" do
      expect(active).to eq("command-palette-create-task")
    end

    it "points the combobox at the selected row" do
      expect(query["aria-activedescendant"]).to eq("command-palette-create-task")
    end

    it "holds the task back until you ask for one" do
      expect(page).to have_no_css("#command-palette-kind-task")
    end
  end

  describe "opening it with ⌘K" do
    before { find("body").send_keys([:meta, "k"]) }

    it "opens the dialog" do
      expect(page).to have_css("dialog#command-palette[open]")
    end
  end

  describe "opening it with Ctrl+K" do
    before { find("body").send_keys([:control, "k"]) }

    it "opens the dialog" do
      expect(page).to have_css("dialog#command-palette[open]")
    end
  end

  describe "opening it with a slash" do
    before { find("body").send_keys("/") }

    it "opens the dialog" do
      expect(page).to have_css("dialog#command-palette[open]")
    end
  end

  describe "typing a slash into a field" do
    before do
      visit "/admin/tasks/new"
      fill_in("task[title]", with: "half/day")
    end

    it "leaves the palette shut" do
      expect(page).to have_no_css("dialog#command-palette[open]")
    end

    it "keeps the slash in the field" do
      expect(page).to have_field("task[title]", with: "half/day")
    end

    it "still opens on the shortcut" do
      find_field("task[title]").send_keys([:meta, "/"])

      expect(page).to have_css("dialog#command-palette[open]")
    end
  end

  describe "typing a query" do
    before do
      open_palette
      query.send_keys(*"mess".chars)
    end

    it "keeps the rows that match" do
      expect(page).to have_css("#command-palette-messages")
    end

    it "drops the rows that do not" do
      expect(page).to have_no_css("#command-palette-posts")
    end

    it "moves the selection onto the first match" do
      expect(active).to eq("command-palette-messages")
    end

    it "announces how many rows are left" do
      expect(page).to have_css("[data-palette-status]", text: "1 result", visible: :all)
    end

    it "offers a row that writes the query down as a task" do
      expect(page).to have_css("#command-palette-create-task-typed", text: "Create task “mess”")
    end

    it "offers a row that sees every result for the query" do
      expect(page).to have_css("#command-palette-see-all", text: "See all results for “mess”")
    end
  end

  describe "running Create task with a query" do
    before do
      open_palette
      query.send_keys(*"Buy stamps".chars)
      find_by_id("command-palette-create-task-typed").click
    end

    it "opens the create task dialog with the title filled", :aggregate_failures do
      expect(page).to have_css("dialog#task-create[open]")
      expect(page).to have_field("task[title]", with: "Buy stamps")
    end
  end

  describe "running Keyboard shortcuts" do
    before do
      open_palette
      query.send_keys(*"keyboard".chars)
      query.send_keys(:enter)
    end

    it "opens the key help" do
      expect(page).to have_css("dialog#key-help[open]")
    end
  end

  describe "running Toggle theme" do
    def theme = evaluate_script("document.documentElement.dataset.siteTheme")

    def toggle
      open_palette
      query.send_keys(*"toggle theme".chars, :enter)
      theme
    end

    it "flips the theme each time" do
      expect(toggle).not_to eq(toggle)
    end
  end

  describe "the Actions group" do
    before { open_palette }

    it "holds Create task and Create journal entry", :aggregate_failures do
      within("[aria-labelledby='command-palette-group-actions']") do
        expect(page).to have_css(".pal-g", text: /actions/i)
        expect(page).to have_css("#command-palette-create-task", text: "Create task")
        expect(page).to have_css("#command-palette-create-journal-entry", text: "Create journal entry")
      end
    end
  end

  describe "the Create task command" do
    before { open_palette }

    it "is on the list before you type" do
      expect(page).to have_css("#command-palette-create-task", text: "Create task")
    end

    it "is found by what it does" do
      query.send_keys(*"new task".chars)

      expect(active).to eq("command-palette-create-task")
    end
  end

  describe "typing part of an action's name" do
    before do
      open_palette
      query.send_keys(*"crea".chars)
    end

    it "lists the action" do
      expect(page).to have_css("#command-palette-create-task", text: "Create task")
    end
  end

  describe "a query that matches an action and a task" do
    before do
      create(:task, title: "Create the invoice")
      open_palette
      query.send_keys(*"create".chars)
      page.assert_selector(".pal-r", text: "Create the invoice")
    end

    it "lists the action above the task" do
      rows = page.all(".pal-r").map(&:text)

      expect(rows.index { it.include?("Create task") }).to be < rows.index { it.include?("Create the invoice") }
    end
  end

  describe "searching the tasks" do
    before do
      open_palette
      query.send_keys(*"accountant".chars)
    end

    it "finds the unfinished task under Records", :aggregate_failures do
      expect(page).to have_css(".pal-g", text: /records/i)
      expect(page).to have_css(".pal-r", text: "Email the accountant")
    end

    it "labels it with its kind" do
      expect(page).to have_css(".pal-r", text: "Email the accountant") { it.has_css?(".pal-r-sub", text: "task") }
    end
  end

  describe "searching the decisions" do
    before do
      create(:decision, title: "Pick a blimp hangar")
      open_palette
      query.send_keys(*"hangar".chars)
    end

    it "finds the decision, labelled as one" do
      expect(page).to have_css(".pal-r", text: "Pick a blimp hangar") { it.has_css?(".pal-r-sub", text: "decision") }
    end
  end

  describe "searching a phrase from a journal entry" do
    let!(:entry) { create(:journal_entry, body: "Walked the levee at dawn\nThe river ran high") }

    before do
      open_palette
      query.send_keys(*"levee".chars)
    end

    it "lists the entry under Records, labelled with its kind", :aggregate_failures do
      within("[aria-labelledby='command-palette-group-records']") do
        expect(page).to have_css(".pal-g", text: /records/i)
        expect(page).to have_css(".pal-r-label", text: "Walked the levee at dawn")
        expect(page).to have_css(".pal-r-sub", text: "journal")
      end
    end

    it "shows a short match" do
      expect(page).to have_css(".pal-r-match", text: /levee/)
    end

    it "opens it on enter" do
      page.assert_selector(".pal-r", text: "Walked the levee at dawn")
      query.send_keys(:enter)

      expect(page).to have_current_path("/admin/journal?to=#{entry.entry_date.iso8601}")
    end
  end

  describe "asking the search" do
    def asks = request_gate.count(search_path)

    it "waits until you type" do
      open_palette

      expect(asks).to eq(0)
    end

    describe "typing fast" do
      before do
        open_palette
        query.send_keys(*"accountant".chars)
        page.assert_selector(".pal-r", text: "Email the accountant")
      end

      it "asks once" do
        expect(asks).to eq(1)
      end
    end

    describe "a reply that a newer one overtakes" do
      before do
        create(:task, title: "Call the plumber")
        open_palette
        hold = request_gate.hold(search_path)
        query.send_keys(*"plumber".chars)
        hold.wait_for_arrival
        query.send_keys(*Array.new(7, :backspace), *"accountant".chars)
        page.assert_selector(".pal-r", text: "Email the accountant")
        hold.release
        Timeout.timeout(5) { sleep 0.05 until request_gate.answered(search_path) >= 2 }
        page.driver.wait_for_network_idle
      end

      it "keeps the newer results", :aggregate_failures do
        expect(page).to have_css(".pal-r", text: "Email the accountant")
        expect(page).to have_no_css(".pal-r", text: "Call the plumber")
      end
    end

    describe "opening it again" do
      before do
        open_palette
        query.send_keys(*"accountant".chars)
        page.assert_selector(".pal-r", text: "Email the accountant")
        query.send_keys(:escape)
        open_palette
      end

      it "clears the last results" do
        expect(page).to have_no_css(".pal-r", text: "Email the accountant")
      end
    end
  end

  describe "the See all results row" do
    before { open_palette }

    it "stays away until you type" do
      expect(page).to have_no_css("#command-palette-see-all")
    end

    describe "after a query" do
      before do
        9.times { create(:task, title: "Call the plumber #{it}") }
        query.send_keys(*"plumber".chars)
        page.assert_selector(".pal-r", text: "Call the plumber", count: 8)
      end

      it "sits below the results, above Create task" do
        expect(page.all(".pal-r").last(2).map { it[:id] })
          .to eq(%w[command-palette-see-all command-palette-create-task-typed])
      end

      it "opens the search screen with the same query, every match listed", :aggregate_failures do
        find_by_id("command-palette-see-all").click

        expect(page).to have_current_path("/admin/search?q=plumber")
        expect(page).to have_css(".li-title", text: "Call the plumber", count: 9)
      end

      it "opens it from the keyboard" do
        query.send_keys(:end, :up, :enter)

        expect(page).to have_current_path("/admin/search?q=plumber")
      end
    end
  end

  describe "searching more records than it shows" do
    before do
      9.times { create(:task, title: "Call the plumber #{it}") }
      open_palette
      query.send_keys(*"plumber".chars)
    end

    it "shows the top eight" do
      expect(page).to have_css(".pal-r", text: "Call the plumber", count: 8)
    end
  end

  describe "running a task row" do
    before do
      open_palette
      query.send_keys(*"accountant".chars)
      page.assert_selector(".pal-r", text: "Email the accountant")
      query.send_keys(:enter)
    end

    it "opens the task" do
      expect(page).to have_current_path(%r{\A/admin/tasks/\d+\z})
    end
  end

  describe "hovering a row" do
    before do
      open_palette
      find_by_id("command-palette-messages").hover
    end

    it "picks it out" do
      expect(active).to eq("command-palette-messages")
    end
  end

  describe "moving with the arrows" do
    before do
      open_palette
      query.send_keys(:down)
    end

    it "steps down the list" do
      expect(active).to eq("command-palette-create-decision")
    end

    it "steps back up" do
      query.send_keys(:up)

      expect(active).to eq("command-palette-create-task")
    end

    it "stops at the top" do
      query.send_keys(:up, :up)

      expect(active).to eq("command-palette-create-task")
    end
  end

  describe "pressing enter" do
    before do
      open_palette
      query.send_keys(*"mess".chars, :enter)
    end

    it "goes to the section" do
      expect(page).to have_current_path("/admin/messages")
    end
  end

  describe "running the Create task command" do
    before do
      visit "/admin/posts"
      open_palette
      query.send_keys(*"create task".chars, :enter)
    end

    it "shuts the palette" do
      expect(page).to have_no_css("dialog#command-palette[open]")
    end

    it "opens the new task dialog on the page you are on", :aggregate_failures do
      expect(page).to have_css("dialog#task-create[open]")
      expect(page).to have_current_path("/admin/posts")
    end

    describe "saving the dialog" do
      before do
        within("dialog#task-create") do
          fill_in("task[title]", with: "Call the plumber")
          select("today", from: "task[list]")
          click_button("Create task")
        end
      end

      it "writes the task down in the list it names" do
        expect(page).to have_css(".task-title", text: "Call the plumber")
      end

      it "says so" do
        expect(page).to have_css("[data-toast]", text: "Task captured")
      end
    end
  end

  describe "searching for log work" do
    before do
      open_palette
      query.send_keys(*"log work".chars)
    end

    it "finds no action", :aggregate_failures do
      expect(page).to have_css("dialog#command-palette[open]")
      expect(page).to have_no_css("[aria-labelledby='command-palette-group-actions'] [data-palette-option]")
    end
  end

  describe "the Create decision command" do
    before { open_palette }

    it "is listed under the actions when I type decision" do
      query.send_keys(*"decision".chars)

      within("[aria-labelledby='command-palette-group-actions']") do
        expect(page).to have_css("#command-palette-create-decision", text: "Create decision")
      end
    end

    it "is picked first when I type create decision" do
      query.send_keys(*"create decision".chars)

      expect(active).to eq("command-palette-create-decision")
    end
  end

  describe "running the Create decision command" do
    before do
      visit "/admin/posts"
      open_palette
      query.send_keys(*"create decision".chars, :enter)
    end

    it "opens the new decision form" do
      expect(page).to have_current_path("/admin/decisions/new")
    end
  end

  describe "the Create journal entry command" do
    before { open_palette }

    it "is found by what it does" do
      query.send_keys(*"write in the journal".chars)

      expect(active).to eq("command-palette-create-journal-entry")
    end

    it "drops out when the query does not match" do
      query.send_keys(*"mess".chars)

      expect(page).to have_no_css("#command-palette-create-journal-entry")
    end
  end

  describe "running the Create journal entry command" do
    before do
      visit "/admin/posts"
      open_palette
      query.send_keys(*"journal entry".chars, :enter)
    end

    it "opens the journal modal where you are", :aggregate_failures do
      expect(page).to have_css("dialog#journal-write[open]")
      expect(page).to have_current_path("/admin/posts")
    end

    it "puts the cursor in the entry field" do
      expect(page).to have_css("#journal-write-body:focus")
    end
  end

  describe "typing post" do
    before do
      open_palette
      query.send_keys(*"post".chars)
    end

    it "lists New post and New social post", :aggregate_failures do
      within("[aria-labelledby='command-palette-group-actions']") do
        expect(page).to have_css("#command-palette-new-post", text: "New post")
        expect(page).to have_css("#command-palette-new-social-post", text: "New social post")
      end
    end
  end

  describe "running the New post command" do
    before do
      open_palette
      query.send_keys(*"new post".chars, :enter)
    end

    it "opens the new post form" do
      expect(page).to have_current_path("/admin/posts/new")
    end
  end

  describe "running the New social post command" do
    before do
      visit "/admin/posts"
      open_palette
      query.send_keys(*"new social post".chars, :enter)
    end

    it "opens the composer" do
      expect(page).to have_current_path("/admin/social?write=1")
    end

    it "puts the cursor in it" do
      expect(page).to have_css("[data-social-part] [data-social-body]:focus")
    end
  end

  describe "the Saved views group" do
    def asks = request_gate.count("/admin/saved-views/palette")

    def group = "[aria-labelledby='command-palette-group-saved-views']"

    let!(:drafts) { create(:saved_view, screen: "posts", name: "Stale drafts", filters: { "status" => "draft" }) }

    before do
      create(:saved_view, screen: "tasks", name: "Next up", filters: { "filter" => "next" })
      visit "/admin"
    end

    it "asks for no view until the palette opens", :aggregate_failures do
      expect(asks).to eq(0)

      open_palette
      page.assert_selector("#command-palette-saved-view-#{drafts.id}", visible: :all)

      expect(asks).to eq(1)
    end

    it "holds the views back until you type" do
      open_palette
      page.assert_selector("#command-palette-saved-view-#{drafts.id}", visible: :all)

      expect(page).to have_no_css(group)
    end

    describe "typing part of a view's name" do
      before do
        open_palette
        query.send_keys(*"stale".chars)
      end

      it "lists the view under Saved views with its screen", :aggregate_failures do
        within(group) do
          expect(page).to have_css(".pal-g", text: /saved views/i)
          expect(page).to have_css(".pal-r", text: /Stale drafts\s*posts/)
        end
      end

      it "leaves out the views that do not match" do
        expect(page).to have_no_css(".pal-r", text: "Next up")
      end

      it "opens the view's screen with its filters set on enter" do
        page.assert_selector(".pal-r", text: "Stale drafts")
        query.send_keys(:enter)

        expect(page).to have_current_path("/admin/posts?status=draft")
      end
    end

    describe "after deleting a view and reloading" do
      before do
        SavedViews::Slice["repos.saved_view_mutations"].delete(drafts.id)
        visit "/admin"
        open_palette
        query.send_keys(*"next".chars)
        page.assert_selector(".pal-r", text: "Next up")
        query.send_keys(*Array.new(4, :backspace), *"stale".chars)
      end

      it "drops the deleted view" do
        expect(page).to have_no_css(".pal-r", text: "Stale drafts")
      end
    end

    describe "on a phone" do
      before do
        page.driver.resize(375, 800)
        visit "/admin"
        click_button(class: "top-bar-search")
        query.send_keys(*"stale".chars)
      end

      it "fits without scrolling the page sideways", :aggregate_failures do
        expect(page).to have_css(".pal-r", text: "Stale drafts")
        expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.documentElement)")).to be(false)
      end

      it "opens the view where you tap" do
        find(".pal-r", text: "Stale drafts").click

        expect(page).to have_current_path("/admin/posts?status=draft")
      end
    end

    %w[light dark].each do |scheme|
      it "passes axe in #{scheme} mode" do
        emulate_color_scheme(scheme)
        open_palette
        query.send_keys(*"stale".chars)
        page.assert_selector(".pal-r", text: "Stale drafts")

        expect(axe_breaches).to be_empty
      end
    end
  end

  describe "pressing escape" do
    before do
      open_palette
      page.assert_selector("dialog#command-palette[open]")
      query.send_keys(:escape)
    end

    it "closes the palette" do
      expect(page).to have_no_css("dialog#command-palette[open]")
    end
  end

  describe "clicking outside" do
    before do
      open_palette
      page.assert_selector("dialog#command-palette[open]")
      page.driver.browser.mouse.click(x: 5, y: 5)
    end

    it "closes the palette" do
      expect(page).to have_no_css("dialog#command-palette[open]")
    end

    it "opens again with the keyboard" do
      page.assert_no_selector("dialog#command-palette[open]")
      open_palette

      expect(page).to have_css("dialog#command-palette[open]")
    end
  end

  describe "on a phone" do
    def edge(selector, side) = evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().#{side}")

    before do
      page.driver.resize(375, 800)
      visit "/admin"
    end

    it "offers a button to tap" do
      expect(page).to have_button(class: "top-bar-search")
    end

    it "does not scroll the page sideways" do
      expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.documentElement)")).to be(false)
    end

    it "gives the button a 44px square to tap", :aggregate_failures do
      expect(edge(".top-bar-search", :width)).to be >= 44
      expect(edge(".top-bar-search", :height)).to be >= 44
    end

    describe "tapping it" do
      before { click_button(class: "top-bar-search") }

      it "opens the palette" do
        expect(page).to have_css("dialog#command-palette[open]")
      end

      it "goes where you tap" do
        find_by_id("command-palette-messages").click

        expect(page).to have_current_path("/admin/messages")
      end

      {
        "command-palette-new-post" => "/admin/posts/new",
        "command-palette-new-social-post" => "/admin/social?write=1",
      }.each do |id, path|
        it "goes to #{path} from #{id}" do
          find_by_id(id).click

          expect(page).to have_current_path(path)
        end
      end
    end
  end
end
