# frozen_string_literal: true

RSpec.describe "Admin row actions", type: :feature do
  def actions = first(row).find(".hov", visible: :all)

  def emulate_touch
    page.driver.browser.page.command("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 1)
    visit screen
  end

  def opacity(element = actions) = evaluate_script("getComputedStyle(arguments[0]).opacity", element).to_f

  def press(*keys) = page.driver.browser.keyboard.type(*keys)

  def shown(read)
    evaluate_script(<<~JS, actions)
      [...arguments[0].querySelectorAll(".bt")].filter((b) => b.checkVisibility()).map((b) => #{read})
    JS
  end

  before { sign_in_to_admin }

  shared_examples "hidden row actions" do
    before { visit screen }

    it "hides them until the row is hovered" do
      expect { opacity }.to eventually(eq(0))
    end

    it "shows them on hover" do
      first(row).hover

      expect { opacity }.to eventually(eq(1))
    end

    it "shows them when focus moves into them" do
      execute_script(<<~JS, actions)
        const actions = arguments[0];
        const control = actions.querySelector(":is(button, a[href], summary):not([hidden])");
        (control ?? actions.parentElement.querySelector("input")).focus();
      JS

      expect { opacity }.to eventually(eq(1))
    end

    it "shows them at all times on a touch screen" do
      emulate_touch

      expect { opacity }.to eventually(eq(1))
    end

    it "gives each one a label for screen readers" do
      expect(shown('b.getAttribute("aria-label") || b.textContent.trim()')).to all(match(/\S/))
    end

    it "draws them as 32px icon buttons" do
      expect(shown("b.getBoundingClientRect().height")).to all(eq(32))
    end
  end

  describe "a task row" do
    let(:screen) { "/admin/tasks?filter=next" }
    let(:row) { ".task" }

    before { create(:task, title: "Write the brief") }

    it_behaves_like "hidden row actions"

    describe "reached with j" do
      before do
        visit screen
        press("j")
      end

      it "shows its actions" do
        expect { opacity }.to eventually(eq(1))
      end

      it "marks the row with the green bar" do
        bar = evaluate_script("getComputedStyle(arguments[0]).boxShadow", find(row))

        expect(bar).to include("-12px 0px 0px -9px")
      end
    end
  end

  describe "a pull in row" do
    let(:screen) { "/admin/tasks?filter=today" }
    let(:row) { ".task-pull .li" }

    before { create(:task, title: "Write the brief") }

    it_behaves_like "hidden row actions"
  end

  describe "an attention row" do
    let(:screen) { "/admin" }
    let(:row) { "[data-attention] .li" }

    before { create(:post, :draft, title: "Old draft", updated_at: days_ago(60)) }

    it_behaves_like "hidden row actions"
  end

  describe "a journal entry" do
    let(:screen) { "/admin/journal" }
    let(:row) { ".journal-entry" }

    before { create(:journal_entry) }

    it_behaves_like "hidden row actions"
  end

  describe "a project card" do
    let(:screen) { "/admin/projects" }
    let(:row) { ".project-card" }

    before { create(:project) }

    it_behaves_like "hidden row actions"
  end

  describe "a decision option" do
    let(:decision) { create(:decision) }
    let(:screen) { "/admin/decisions/#{decision.id}" }
    let(:row) { ".decision-option" }

    before { create(:decision_option, decision_id: decision.id) }

    it_behaves_like "hidden row actions"
  end

  describe "a task rule" do
    let(:screen) { "/admin/tasks/rules" }
    let(:row) { ".rule-row" }

    before { Tasks::Slice["operations.save_task_rule"].call({ pattern: "aaronmallen/*", tags: "projects" }) }

    it_behaves_like "hidden row actions"
  end

  describe "a work history row" do
    let(:screen) { "/admin/projects?filter=work" }
    let(:row) { ".work-row" }

    before { create(:work_entry) }

    it_behaves_like "hidden row actions"
  end
end
