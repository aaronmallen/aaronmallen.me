# frozen_string_literal: true

RSpec.describe "Admin bulk task actions", type: :feature do
  let(:repo) { Tasks::Slice["repos.task_queries"] }

  def acts = find("[data-bulk-acts]", visible: :all)

  def all_box = find("[data-bulk-all] input")

  def box(title) = find(".task", text: title).find("input[name='ids[]']")

  def bulk(button, **fields)
    within("form#task-bulk") do
      select(fields[:to], from: "to") if fields[:to]
      fill_in("tag", with: fields[:tag]) if fields[:tag]
      click_button(button)
    end
  end

  def tagged(name)
    names = Tasks::Slice["relations.task_tags"].names_by_task(repo.all_open.map(&:id))

    names.filter_map { |id, tags| repo.by_id(id).title if tags.include?(name) }
  end

  def ticked
    page.all(".task").select { it.has_css?("input:checked", wait: false) }.map { it.find(".task-title").text }
  end

  before do
    %w[first second third].each_with_index { |title, index| create(:task, title:, position: index + 1) }
    create(:task, :someday, title: "elsewhere")
    sign_in_to_admin
  end

  describe "with scripts on" do
    before { visit "/admin/tasks?filter=next" }

    it "hides the actions while nothing is ticked" do
      expect(acts).not_to be_visible
    end

    it "shows the actions once a row is ticked" do
      box("second").check

      expect(acts).to be_visible
    end

    it "counts the ticked rows" do
      box("first").check
      box("third").check

      expect(page).to have_css("[data-bulk-count]", exact_text: "2 ticked")
    end

    it "hides the actions again once every box is clear" do
      box("second").check
      box("second").uncheck

      expect(acts).not_to be_visible
    end

    it "ticks every row on the page with select all" do
      all_box.check

      expect(ticked).to eq(%w[first second third])
    end

    it "clears every row when select all is cleared" do
      all_box.check
      all_box.uncheck

      expect(ticked).to be_empty
    end

    it "marks select all as partly ticked when only some rows are" do
      box("first").check

      expect(evaluate_script("document.querySelector('[data-bulk-all] input').indeterminate")).to be(true)
    end

    it "finishes the ticked tasks and leaves the rest", :aggregate_failures do
      box("first").check
      box("third").check
      within("form#task-bulk") { click_button("Done") }

      expect(page).to have_css("[data-toast] .toast", text: "Finished 2 tasks")
      expect(repo.all_open.map(&:title)).to contain_exactly("second", "elsewhere")
    end

    it "cancels every task on the page and none on another list", :aggregate_failures do
      all_box.check
      within("form#task-bulk") { click_button("Cancel") }

      expect(page).to have_css("[data-toast] .toast", text: "Canceled 3 tasks")
      expect(repo.all_open.map(&:title)).to eq(["elsewhere"])
    end

    it "moves the ticked tasks to the list picked", :aggregate_failures do
      box("first").check
      bulk("Move", to: "Someday")

      expect(page).to have_css("[data-toast] .toast", text: "Moved 1 task to someday")
      expect(repo.in_list("someday").map(&:title)).to contain_exactly("first", "elsewhere")
    end

    it "tags rather than finishes when Enter goes in the tag field", :aggregate_failures do
      box("first").check
      find("form#task-bulk input[name='tag']").send_keys("home", :enter)

      expect(page).to have_css("[data-toast] .toast", text: "Tagged 1 task home")
      expect(tagged("home")).to eq(["first"])
    end

    it "asks before it deletes", :aggregate_failures do
      box("second").check
      within("form#task-bulk") { click_button("Delete") }
      confirm_yes

      expect(page).to have_css("[data-toast] .toast", text: "Deleted 1 task")
      expect(repo.all_open.map(&:title)).to contain_exactly("first", "third", "elsewhere")
    end

    it "keeps the tasks when the delete is declined" do
      box("second").check
      within("form#task-bulk") { click_button("Delete") }
      confirm_no

      expect(repo.all_open.size).to eq(4)
    end
  end

  describe "select all on a paged list" do
    before do
      lower_page_size(:admin, to: 2)
      visit "/admin/tasks?filter=next"
    end

    it "ticks only the rows on the page", :aggregate_failures do
      all_box.check
      within("form#task-bulk") { click_button("Done") }

      expect(page).to have_css("[data-toast] .toast", text: "Finished 2 tasks")
      expect(repo.all_open.map(&:title)).to contain_exactly("third", "elsewhere")
    end
  end
end
