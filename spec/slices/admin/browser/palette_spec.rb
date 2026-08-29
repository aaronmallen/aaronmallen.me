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
      visit "/admin/tasks"
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
      expect(page).to have_css("[data-palette-status]", text: "2 results", visible: :all)
    end

    it "offers to write the query down as a task" do
      expect(page).to have_css("#command-palette-add", text: "Add “mess” to today's sprint")
    end
  end

  describe "typing a query with dollar signs" do
    before { open_palette }

    it "shows a double dollar as typed" do
      query.send_keys(*"Pay $$ bill".chars)

      expect(page).to have_css("#command-palette-add", text: "Add “Pay $$ bill” to today's sprint")
    end

    it "shows a dollar and ampersand as typed" do
      query.send_keys(*"x$&y".chars)

      expect(page).to have_css("#command-palette-add", text: "Add “x$&y” to today's sprint")
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

  describe "pressing enter on the row that writes" do
    before do
      open_palette
      query.send_keys(*"Call the plumber".chars, :end, :enter)
    end

    it "writes the task down in today's sprint" do
      expect(page).to have_css(".task-title", text: "Call the plumber")
    end

    it "says so" do
      expect(page).to have_css("[data-toast]", text: "Task captured")
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
