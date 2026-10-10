# frozen_string_literal: true

RSpec.describe "Admin task contributors", :frozen_clock, type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:repo) { Tasks::Slice["repos.task_queries"] }
  let(:task) { create(:task, title: "Ship the editor") }
  let(:new_agent) { "task[contributors][agents][new]" }

  def credit(model: "claude-opus-5-5") = create(:task_contributor, task_id: task.id, model:)

  def credits_fact = page.find(".task-fact", text: i18n.t("ui.components.tasks.facts.contributors")).find("dd").text

  def form = page.find("#task-#{task.id}-form")

  def held
    form.all("[name^='task[']", visible: :all).each_with_object({}) do |field, fields|
      next if field[:type] == "checkbox" && !field.checked?

      fields[field[:name]] = field.value.to_s
    end
  end

  def keep_box = form.find("input[type='checkbox'][name='task[contributors][agents][0][keep]']")

  def open_edit = get("/admin/tasks/#{task.id}/edit")

  def owner_box = form.find("input[type='checkbox'][name='task[contributors][owner]']")

  def page = Capybara.string(last_response.body)

  def save(**changes)
    open_edit
    post "/admin/tasks/#{task.id}", { _csrf_token: admin_csrf_token, filter: "next", **held, **changes }
  end

  def stored = repo.by_id(task.id).contributors.map { [it.kind, it.agent, it.model] }

  before { sign_in_to_admin }

  describe "the edit page" do
    it "checks me for a task with no contributors", :aggregate_failures do
      open_edit

      expect(owner_box).to be_checked
      expect(form).to have_no_css("input[name$='[keep]']")
    end

    it "lists each agent with its model, checked", :aggregate_failures do
      credit
      open_edit

      expect(keep_box).to be_checked
      expect(keep_box.find(:xpath, "..")).to have_text("claude-code on claude-opus-5-5")
      expect(owner_box).not_to be_checked
    end

    it "offers empty fields to add an agent and its model", :aggregate_failures do
      open_edit

      expect(form.find_field("#{new_agent}[agent]").value).to be_nil
      expect(form.find_field("#{new_agent}[model]").value).to be_nil
    end

    it "keeps the contributor fields off the new task page" do
      get "/admin/tasks/new"

      expect(page).to have_no_css("[name^='task[contributors]']")
    end
  end

  describe "saving from the edit page" do
    it "adds an agent with its model beside me" do
      save("#{new_agent}[agent]" => "claude-code", "#{new_agent}[model]" => "claude-opus-5-5")

      expect(stored).to eq([["owner", nil, nil], %w[agent claude-code claude-opus-5-5]])
    end

    it "adds an agent alone when I take myself off" do
      save(
        "task[contributors][owner]" => "0",
        "#{new_agent}[agent]" => " claude-code ", "#{new_agent}[model]" => "claude-sonnet-5",
      )

      expect(stored).to eq([%w[agent claude-code claude-sonnet-5]])
    end

    it "adds me to a task an agent did" do
      credit
      save("task[contributors][owner]" => "1")

      expect(stored).to eq([["owner", nil, nil], %w[agent claude-code claude-opus-5-5]])
    end

    it "removes a contributor I uncheck" do
      create(:task_contributor, :owner, task_id: task.id)
      credit
      save("task[contributors][agents][0][keep]" => "0")

      expect(stored).to eq([["owner", nil, nil]])
    end

    it "writes no rows when the contributors did not change" do
      save

      expect(stored).to be_empty
    end

    it "leaves a task's rows alone when the form sends no contributors" do
      credit
      post "/admin/tasks/#{task.id}", { _csrf_token: admin_csrf_token, task: { title: "Ship the editor" } }

      expect(stored).to eq([%w[agent claude-code claude-opus-5-5]])
    end

    it "shows the saved contributors on the task page" do
      save("#{new_agent}[agent]" => "claude-code", "#{new_agent}[model]" => "claude-opus-5-5")
      get "/admin/tasks/#{task.id}"

      expect(credits_fact).to eq("Me, claude-code on claude-opus-5-5")
    end

    it "checks the saved contributors when the editor opens again", :aggregate_failures do
      save("#{new_agent}[agent]" => "claude-code", "#{new_agent}[model]" => "claude-opus-5-5")
      open_edit

      expect(owner_box).to be_checked
      expect(keep_box).to be_checked
    end
  end

  describe "an agent without a model" do
    before { save("#{new_agent}[agent]" => "claude-code") }

    it "answers 422 and says what went wrong", :aggregate_failures do
      expect(last_response.status).to eq(422)
      expect(page.find("#task-#{task.id}-contributors-error"))
        .to have_text(i18n.t("ui.components.tasks.field_error.contributors.format"))
    end

    it "keeps what was typed", :aggregate_failures do
      expect(owner_box).to be_checked
      expect(form).to have_field("#{new_agent}[agent]", with: "claude-code")
    end

    it "writes nothing" do
      expect(stored).to be_empty
    end
  end

  describe "the task page" do
    it "lists me for a task with no contributors" do
      get "/admin/tasks/#{task.id}"

      expect(credits_fact).to eq("Me")
    end

    it "lists each agent with its model" do
      credit
      credit(model: "claude-sonnet-5")
      get "/admin/tasks/#{task.id}"

      expect(credits_fact).to eq("claude-code on claude-opus-5-5, claude-code on claude-sonnet-5")
    end
  end
end
