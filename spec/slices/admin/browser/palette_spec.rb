# frozen_string_literal: true

RSpec.describe "Admin command palette", type: :feature do
  def active = evaluate_script("document.querySelector('[data-palette-option][aria-selected=\"true\"]').id")

  def open_palette = find("body").send_keys([:meta, "/"])

  def query = find("[data-palette-query]")

  before do
    create(:task, title: "Email the accountant")
    create(:message)
    sign_in_to_admin
    visit "/admin"
  end

  it "stays shut until something opens it" do
    expect(page).to have_no_css("dialog#command-palette[open]")
  end

  it "says where you are on every screen" do
    visit "/admin/posts"

    expect(page).to have_css(".ctx-where", text: %r{Publish\s+/\s+posts})
  end

  it "flags the unread message on the jump button" do
    expect(page).to have_css(".ctx-btn.jump .ctx-dot")
  end

  describe "opening it with the keyboard" do
    before { open_palette }

    it "opens the dialog" do
      expect(page).to have_css("dialog#command-palette[open]")
    end

    it "puts the cursor in the query box" do
      expect(evaluate_script("document.activeElement.getAttribute('role')")).to eq("combobox")
    end

    it "lists every section, under its group", :aggregate_failures do
      expect(page).to have_css(".pal-g", text: /daily/i)
      expect(page).to have_css("#command-palette-messages")
    end

    it "selects the first row" do
      expect(active).to eq("command-palette-today")
    end

    it "points the combobox at the selected row" do
      expect(query["aria-activedescendant"]).to eq("command-palette-today")
    end

    it "holds the task back until you ask for one" do
      expect(page).to have_no_css("#command-palette-group-tasks")
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

    it "offers no row that writes the query down as a task" do
      expect(page).to have_no_css(".pal-r", text: "mess”")
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

  describe "searching the tasks" do
    before do
      open_palette
      query.send_keys(*"accountant".chars)
    end

    it "finds the unfinished task", :aggregate_failures do
      expect(page).to have_css(".pal-g", text: /tasks/i)
      expect(page).to have_css(".pal-r", text: "Email the accountant")
    end

    it "says which list the task sits in" do
      expect(page).to have_css(".pal-r", text: "in next")
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
      expect(active).to eq("command-palette-tasks")
    end

    it "steps back up" do
      query.send_keys(:up)

      expect(active).to eq("command-palette-today")
    end

    it "stops at the top" do
      query.send_keys(:up, :up)

      expect(active).to eq("command-palette-today")
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

    it "opens the journal page" do
      expect(page).to have_current_path("/admin/journal?write=1")
    end

    it "puts the cursor in the entry field" do
      expect(page).to have_css("#journal-entry textarea[name='entry[body]']:focus")
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

  describe "on a phone" do
    def edge(selector, side) = evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().#{side}")

    before do
      page.driver.resize(375, 800)
      visit "/admin"
    end

    it "offers a button to tap" do
      expect(page).to have_button(class: "slash")
    end

    it "does not scroll the page sideways" do
      expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.documentElement)")).to be(false)
    end

    it "keeps the button off the footer at the foot of the page" do
      execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")

      expect(edge(".adm-footer-version", :bottom)).to be <= edge(".slash", :top)
    end

    describe "tapping it" do
      before { click_button(class: "slash") }

      it "opens the palette" do
        expect(page).to have_css("dialog#command-palette[open]")
      end

      it "goes where you tap" do
        find_by_id("command-palette-messages").click

        expect(page).to have_current_path("/admin/messages")
      end
    end
  end
end
