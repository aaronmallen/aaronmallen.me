# frozen_string_literal: true

RSpec.describe "Admin bulk select mode", type: :feature do
  def await_refresh
    screen = path.split("?").first
    asked = request_gate.count(screen)
    yield.tap { wait_for_answer(screen, asked + 1) }
  end

  def boxes = page.all("input[name='ids[]']", visible: :all)

  def break_a_setup_step
    <<~JS
      const query = Document.prototype.querySelectorAll;
      Document.prototype.querySelectorAll = function (selector) {
        if (selector === "[data-social-picker]") throw new Error("a broken setup step");
        return query.call(this, selector);
      };
    JS
  end

  def off?(pressed: "false")
    has_css?("button[data-bulk-toggle][aria-pressed='#{pressed}']", text: "Select") &&
      has_css?("form#{form}[data-bulk-off]", visible: :all) && has_no_css?("input[name='ids[]']")
  end

  def select_mode = click_button("Select")

  def ticked = boxes.select(&:checked?).map(&:value)

  shared_examples "a screen with bulk select" do
    before { sign_in_to_admin }

    describe "when an earlier setup step throws on load" do
      let(:cdp) { page.driver.browser.page }
      let!(:script) { cdp.command("Page.addScriptToEvaluateOnNewDocument", source: break_a_setup_step)["identifier"] }

      before { visit path }

      after { cdp.command("Page.removeScriptToEvaluateOnNewDocument", identifier: script) }

      it "shows Select with select mode off" do
        expect(off?).to be(true)
      end

      it "turns select mode on from Select" do
        select_mode

        expect(page).to have_css("button[data-bulk-toggle][aria-pressed='true']", text: "Select")
      end
    end

    describe "when a setup step throws after a live refresh" do
      before do
        visit path
        wait_for_stream
        execute_script(break_a_setup_step)
        arrive
      end

      it "still shows Select with select mode off" do
        expect(off?).to be(true)
      end
    end

    describe "with select mode on through a live refresh" do
      before do
        visit path
        wait_for_stream
        select_mode
      end

      describe "with a row ticked" do
        let(:picked) { first(row).find("input[name='ids[]']").tap(&:check).value }

        before do
          picked
          arrive
        end

        it "keeps select mode on and the toggle pressed", :aggregate_failures do
          expect(page).to have_css("button[data-bulk-toggle][aria-pressed='true']", text: "Select")
          expect(page).to have_no_css("form#{form}[data-bulk-off]", visible: :all)
        end

        it "keeps the ticked row" do
          expect(ticked).to eq([picked])
        end
      end

      it "keeps select mode on with nothing ticked", :aggregate_failures do
        arrive

        expect(page).to have_css("button[data-bulk-toggle][aria-pressed='true']", text: "Select")
        expect(page).to have_css("#{row} input[name='ids[]']")
      end
    end

    describe "after leaving select mode on with rows ticked" do
      before do
        visit path
        select_mode
        first(row).find("input[name='ids[]']").check
      end

      it "starts with select mode off and nothing ticked after a reload", :aggregate_failures do
        page.refresh

        expect(off?).to be(true)
        expect(ticked).to be_empty
      end

      it "starts with select mode off and nothing ticked on a visit from another page", :aggregate_failures do
        visit "/admin"
        visit path

        expect(off?).to be(true)
        expect(ticked).to be_empty
      end
    end
  end

  describe "on tasks" do
    let(:form) { "#task-bulk" }
    let(:path) { "/admin/tasks?filter=next" }
    let(:row) { ".task" }

    def arrive = find(".task", text: await_refresh { create(:task, title: "arrived", position: 9) }.title)

    before { %w[first second].each_with_index { |title, index| create(:task, title:, position: index + 1) } }

    it_behaves_like "a screen with bulk select"
  end

  describe "on mail" do
    let(:form) { "#mail-bulk" }
    let(:path) { "/admin/mail" }
    let(:row) { ".mail-row" }

    def arrive = find("#thread-#{await_refresh { create(:message, subject: 'Arrived') }.id}")

    before { Array.new(2) { create(:message) } }

    it_behaves_like "a screen with bulk select"
  end
end
