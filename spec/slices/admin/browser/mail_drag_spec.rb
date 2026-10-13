# frozen_string_literal: true

RSpec.describe "Admin mail drag", type: :feature do
  let!(:newer) { create(:message, subject: "Newer", received_at: Time.now) }
  let!(:older) { create(:message, subject: "Older", received_at: Time.now - 60) }

  def box(element)
    evaluate_script(<<~JS, element)
      (r => ({ x: r.left + r.width / 2, y: r.top + r.height / 2 }))(arguments[0].getBoundingClientRect())
    JS
  end

  def drag(subject, onto, release: true)
    from = box(row(subject))
    mouse = page.driver.browser.mouse

    mouse.move(x: from["x"], y: from["y"]).down
    stroke(from, box(onto)).each { mouse.move(**it) }
    mouse.up if release
  end

  def folder(name) = find(".mail-folders a", text: name)

  def open_mail
    visit "/admin/mail"
    execute_script("window.mailLoaded = true")
  end

  def press(subject)
    from = box(row(subject))
    touch("touchStart", { x: from["x"], y: from["y"] })
  end

  def row(subject) = find(".mail-row", text: subject)

  def stored(thread) = Mail::Slice["repos.thread_queries"].by_id(thread.id)

  def stroke(from, to)
    (1..6).map do |step|
      { x: from["x"] + ((to["x"] - from["x"]) * step / 6), y: from["y"] + ((to["y"] - from["y"]) * step / 6) }
    end
  end

  def swipe_up
    x = box(row("Older"))["x"]
    (0..6).each { touch(it.zero? ? "touchStart" : "touchMove", { x:, y: 450 - (it * 50) }) }
    touch("touchEnd", nil)
  end

  def touch(type, point)
    page.driver.browser.page.command("Input.dispatchTouchEvent", type:, touchPoints: point ? [point] : [])
  end

  def touch_drag(subject, onto, hold: true, release: true)
    from = box(row(subject))
    path = stroke(from, box(onto))

    touch("touchStart", { x: from["x"], y: from["y"] })
    sleep 0.4 if hold
    path.each { touch("touchMove", it) }
    touch("touchEnd", nil) if release
  end

  before do
    sign_in_to_admin
    open_mail
  end

  it "moves a thread dropped on a folder and redraws the list", :aggregate_failures do
    drag("Older", folder("Spam"))

    expect(page).to have_css(".toast", text: "Moved 1 thread to Spam")
    expect(page).to have_no_css(".mail-row", text: "Older")
    expect(stored(older).status).to eq("spam")
    expect(evaluate_script("window.mailLoaded")).to be(true)
  end

  it "moves a thread dragged by touch", :aggregate_failures do
    touch_drag("Older", folder("All mail"))

    expect(page).to have_css(".toast", text: "Archived 1 thread")
    expect(stored(older).archived).to be(true)
  end

  it "opens the thread on a tap" do
    press("Older")
    touch("touchEnd", nil)

    expect(page).to have_css(".mail-row.on", text: "Older")
  end

  describe "on a swipe that does not hold first" do
    before { touch_drag("Older", folder("All mail"), hold: false, release: false) }

    after { touch("touchCancel", nil) }

    it "starts no drag" do
      expect(page).to have_no_css(".mail-row.mail-dragging")
    end
  end

  describe "with a list taller than the window" do
    before do
      30.times { create(:message, received_at: Time.now - 120) }
      page.current_window.resize_to(1280, 500)
      open_mail
    end

    after { page.current_window.resize_to(1280, 800) }

    it "scrolls the list on a swipe" do
      swipe_up

      expect(evaluate_script("window.scrollY")).to be_positive
    end
  end

  describe "with every row picked" do
    before do
      click_button "Select"
      all(".mail-row input[name='ids[]']").each(&:check)
    end

    it "moves every picked thread when a picked row drags", :aggregate_failures do
      drag("Older", folder("Trash"))

      expect(page).to have_css(".toast", text: "Moved 2 threads to Trash")
      expect([stored(newer), stored(older)].map(&:trashed)).to eq([true, true])
    end

    it "shows the ghost, the targets and the faded rows while it drags", :aggregate_failures do
      drag("Older", folder("Spam"), release: false)

      expect(page).to have_css(".mail-ghost", text: "2 threads", visible: :all)
      expect(page).to have_css(".mail-row.mail-dragging", count: 2)
      expect(page).to have_css(".mail-folder.mail-drop", count: 5)
      expect(page).to have_css(".mail-folder.mail-drop.mail-over", text: "Spam")
    end
  end

  describe "below 1180px" do
    before { page.current_window.resize_to(1179, 800) }

    after do
      touch("touchCancel", nil)
      page.current_window.resize_to(1280, 800)
    end

    it "starts no drag, since no folder shows" do
      press("Older")
      sleep 0.4

      expect(page).to have_no_css(".mail-row.mail-dragging")
    end
  end

  it "says a label from another account labels nothing" do
    work = create(:mail_account, name: "work@example.com")
    create(:mail_label, mail_account_id: work.id, name: "Receipts")
    open_mail
    drag("Older", folder("Receipts"))

    expect(page).to have_css(".toast", text: "#Receipts is on another account · nothing labeled")
  end
end
