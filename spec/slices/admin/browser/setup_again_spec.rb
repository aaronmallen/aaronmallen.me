# frozen_string_literal: true

RSpec.describe "Admin scripts after new markup", type: :feature do
  let(:repo) { Tasks::Slice["repos.task_queries"] }

  def active = evaluate_script("document.querySelector('[data-palette-option][aria-selected=\"true\"]').id")

  def center(element)
    box = evaluate_script(<<~JS, element)
      (r => ({ x: r.left + r.width / 2, y: r.top + r.height / 2 }))(arguments[0].getBoundingClientRect())
    JS

    { x: box["x"], y: box["y"] }
  end

  def count_closes
    execute_script(<<~JS)
      window.closes = 0;
      const close = HTMLDialogElement.prototype.close;
      HTMLDialogElement.prototype.close = function (...args) { window.closes += 1; close.apply(this, args); };
    JS
  end

  def drag(title, below:)
    start, *steps = stroke(title, below)
    mouse = page.driver.browser.mouse

    mouse.move(**start).down
    steps.each { mouse.move(**it) }
    mouse.up
  end

  def focused_row = evaluate_script("document.activeElement.closest('[data-key-row]')?.textContent")

  def grip(title) = row(title).find("[data-task-grip]")

  def place_path = "/admin/tasks/#{repo.all_open.find { it.title == 'first' }.id}/place"

  def press(*keys) = page.driver.browser.keyboard.type(*keys)

  def row(title) = find(".task", text: title)

  def shown = page.all(".task-title").map(&:text)

  def stroke(title, below)
    execute_script("arguments[0].scrollIntoView({ block: 'center' })", grip(title))
    from = center(grip(title))
    to = center(row(below))

    (0..6).map { { x: from[:x], y: from[:y] + ((to[:y] + 10 - from[:y]) * it / 6) } }
  end

  def swap
    execute_script(<<~JS)
      for (const part of document.querySelectorAll("main, .top-bar, [data-palette], [data-key-help]")) {
        if (part.isConnected) part.outerHTML = part.outerHTML;
      }
      document.dispatchEvent(new Event("admin:morphed"));
      document.dispatchEvent(new Event("admin:morphed"));
    JS
  end

  before do
    %w[first second third].each_with_index { |title, index| create(:task, title:, position: index + 1) }
    sign_in_to_admin
    visit "/admin/tasks?filter=next"
    swap
  end

  describe "a dialog" do
    before do
      click_button(class: "avatar")
      find(".avatar-menu-item[data-key-help-open]").click
    end

    it "opens from its new trigger" do
      expect(page).to have_css("dialog#key-help[open]")
    end

    it "closes once from its new button", :aggregate_failures do
      count_closes
      find("dialog#key-help [data-dialog-close]").click

      expect(page).to have_no_css("dialog#key-help[open]")
      expect(evaluate_script("window.closes")).to eq(1)
    end
  end

  it "opens the palette from its new trigger and moves one row per arrow" do
    find(".top-bar-search").click
    find("[data-palette-query]").send_keys(:down)

    expect(active).to eq(evaluate_script("document.querySelectorAll('[data-palette-option]:not([hidden])')[1].id"))
  end

  it "moves one row per j" do
    press("j", "j")

    expect(focused_row).to include("second")
  end

  it "saves a drag once", :aggregate_failures do
    drag("first", below: "third")
    Timeout.timeout(5) { sleep 0.05 until request_gate.answered(place_path) >= 1 }

    expect(shown).to eq(%w[second third first])
    expect(request_gate.count(place_path)).to eq(1)
  end
end
