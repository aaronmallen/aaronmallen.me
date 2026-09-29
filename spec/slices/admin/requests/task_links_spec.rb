# frozen_string_literal: true

RSpec.describe "Admin task links", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:task) { create(:task, title: "Ship the links") }
  let(:other) { create(:task, title: "Write the migration") }

  def chips(title)
    row(title).all(".task-link").map do |chip|
      [chip.find(".task-link-label").text, chip.find(".task-key").text, chip.find(".task-link-title").text]
    end
  end

  def find_link(query, id: task.id) = get("/admin/tasks", filter: "next", link: id, link_q: query)

  def link(kind: "blocks", other_id: other.id)
    send_to("/admin/tasks/#{task.id}/links", filter: "next", link: { kind:, other_id: other_id.to_s })
  end

  def link_label(code) = i18n.t(["ui.components.tasks.links.labels", code].join("."))

  def links = Tasks::Slice["relations.task_links"]

  def row(title) = page.find(".task-title", exact_text: title).ancestor(".task")

  def send_to(path, **params)
    post path, { _csrf_token: admin_csrf_token, **params }
  end

  def targets = page.all(".task-link-target").map { it.find(".task-key").text }

  describe "the chips on a row" do
    before do
      sign_in_to_admin
      create(:task_link, from_task_id: task.id, to_task_id: other.id)
    end

    it "reads the type, the other task's key and its title on the task that blocks" do
      get "/admin/tasks", filter: "next"

      expect(chips("Ship the links")).to eq([[link_label(:blocks), "##{other.id}", "Write the migration"]])
    end

    it "reads the reverse on the task that is blocked" do
      get "/admin/tasks", filter: "next"

      expect(chips("Write the migration")).to eq([[link_label(:blocked_by), "##{task.id}", "Ship the links"]])
    end

    it "draws the other task's key as a badge that copies it" do
      get "/admin/tasks", filter: "next"

      expect(row("Ship the links"))
        .to have_css(".task-link .task-key[data-task-key='##{other.id}']")
    end

    it "draws no chips on a task with no links" do
      create(:task, title: "Alone")
      get "/admin/tasks", filter: "next"

      expect(row("Alone")).to have_no_css(".task-links")
    end

    it "reads relates to on both tasks", :aggregate_failures do
      links.where(from_task_id: task.id).update(type: "relates")
      get "/admin/tasks", filter: "next"

      expect(chips("Ship the links").first.first).to eq(link_label(:relates))
      expect(chips("Write the migration").first.first).to eq(link_label(:relates))
    end
  end

  describe "the blocked pill" do
    before do
      sign_in_to_admin
      create(:task_link, from_task_id: other.id, to_task_id: task.id)
    end

    def pill?(title) = row(title).has_css?(".task-meta .pill.pink", text: i18n.t("ui.components.tasks.row.blocked"))

    it "shows while an open task blocks it" do
      get "/admin/tasks", filter: "next"

      expect(pill?("Ship the links")).to be(true)
    end

    it "stays off the task that does the blocking" do
      get "/admin/tasks", filter: "next"

      expect(pill?("Write the migration")).to be(false)
    end

    it "goes once the blocker is complete" do
      send_to("/admin/tasks/#{other.id}/complete", filter: "next")
      get "/admin/tasks", filter: "next"

      expect(pill?("Ship the links")).to be(false)
    end

    it "goes once the blocker is canceled" do
      send_to("/admin/tasks/#{other.id}/cancel", filter: "next")
      get "/admin/tasks", filter: "next"

      expect(pill?("Ship the links")).to be(false)
    end

    it "stays while one blocker is canceled and another is open" do
      create(:task_link, from_task_id: create(:task, :canceled, title: "Drop the migration").id, to_task_id: task.id)
      get "/admin/tasks", filter: "next"

      expect(pill?("Ship the links")).to be(true)
    end

    it "stays off a relates link" do
      links.where(from_task_id: other.id).update(type: "relates")
      get "/admin/tasks", filter: "next"

      expect(pill?("Ship the links")).to be(false)
    end

    it "still lets the blocked task move" do
      send_to("/admin/tasks/#{task.id}/move/someday", filter: "next")

      expect(repo.by_id(task.id).list).to eq("someday")
    end

    it "still lets the blocked task complete" do
      send_to("/admin/tasks/#{task.id}/complete", filter: "next")

      expect(repo.by_id(task.id).status).to eq("done")
    end

    it "still offers the controls on the blocked task", :aggregate_failures do
      get "/admin/tasks", filter: "next"
      row = row("Ship the links")

      expect(row).to have_css("form[action='/admin/tasks/#{task.id}/start']")
      expect(row).to have_css("form[action='/admin/tasks/#{task.id}/move/someday']")
    end
  end

  describe "the picker" do
    before do
      sign_in_to_admin
      task
      other
    end

    it "finds a task by its key" do
      find_link("##{other.id}")

      expect(targets).to eq(["##{other.id}"])
    end

    it "finds a task by its bare number" do
      find_link(other.id.to_s)

      expect(targets).to eq(["##{other.id}"])
    end

    it "finds a task by its title" do
      find_link("migration")

      expect(targets).to eq(["##{other.id}"])
    end

    it "leaves the task itself out" do
      find_link("##{task.id}")

      expect(targets).to be_empty
    end

    it "leaves out a task it already links to" do
      create(:task_link, from_task_id: other.id, to_task_id: task.id)
      find_link("migration")

      expect(targets).to be_empty
    end

    it "offers a canceled task after an open one" do
      canceled = create(:task, :canceled, title: "Drop the migration", position: 1)
      find_link("migration")

      expect(targets).to eq(["##{other.id}", "##{canceled.id}"])
    end

    it "says when nothing matches" do
      find_link("nothing like it")

      expect(page).to have_css(".task-link-editor", text: i18n.t("ui.components.tasks.link_editor.no_match"))
    end

    it "opens the editor on the task it is finding for" do
      find_link("migration")

      expect(page).to have_css("#task-#{task.id}-edit[checked]")
    end

    it "keeps the other editors shut" do
      find_link("migration")

      expect(page).to have_no_css("#task-#{other.id}-edit[checked]")
    end

    it "keeps the query in the field" do
      find_link("migration")

      expect(page.find("#task-#{task.id}-link-other-id").value).to eq("migration")
    end

    it "finds through a plain GET form" do
      get "/admin/tasks", filter: "next"

      expect(page).to have_css(
        "form.task-link-find[method='get'][action='/admin/tasks'] input[name='link'][value='#{task.id}']",
        visible: :all,
      )
    end

    it "posts the link from each match with the type picked beside it", :aggregate_failures do
      find_link("migration")
      form = "task-#{task.id}-link-add"

      expect(page).to have_css("form##{form}[method='post'][action='/admin/tasks/#{task.id}/links']")
      expect(page).to have_css(".task-link-target[form='#{form}'][name='link[other_id]'][value='#{other.id}']")
      expect(page).to have_css("select[form='#{form}'][name='link[kind]']")
    end

    it "finds for a task waiting on the upcoming tab", :aggregate_failures do
      waiting = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today + 1).id)
      get "/admin/tasks", filter: "upcoming", link: waiting.id, link_q: "migration"

      expect(page).to have_css("#task-#{waiting.id}-edit[checked]")
      expect(targets).to eq(["##{other.id}"])
    end

    it "sends the find on the upcoming tab back to that tab" do
      waiting = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today + 1).id)
      get "/admin/tasks", filter: "upcoming"

      form = page.find("#task-#{waiting.id}-link-other-id", visible: :all).ancestor("form")

      expect(form.find("input[name='filter']", visible: :all).value).to eq("upcoming")
    end

    it "offers the four types" do
      get "/admin/tasks", filter: "next"
      options = page.find("#task-#{task.id}-link-kind").all("option").map(&:value)

      expect(options).to eq(%w[blocks blocked_by relates duplicates])
    end
  end

  describe "adding a link" do
    before { sign_in_to_admin }

    it "saves a blocks link from the task" do
      link

      expect(repo.by_id(task.id).links.map { [it.label, it.task.id] }).to eq([["blocks", other.id]])
    end

    it "saves blocked by as a blocks link from the other task" do
      link(kind: "blocked_by")

      stored = links.to_a.map { it.to_h.values_at(:from_task_id, :to_task_id, :type) }

      expect(stored).to eq([[other.id, task.id, "blocks"]])
    end

    %w[relates duplicates].each do |kind|
      it "saves a #{kind} link" do
        link(kind:)

        expect(links.to_a.map { it[:type] }).to eq([kind])
      end
    end

    it "comes back to the list that was open" do
      link

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=next"))
    end

    it "says so" do
      link
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: i18n.t("tasks_page.toasts.linked"))
    end

    it "shows the chip once the page comes back" do
      link
      follow_redirect!

      expect(chips("Ship the links")).to eq([[link_label(:blocks), "##{other.id}", "Write the migration"]])
    end

    it "comes back to the upcoming tab with the error beside a waiting task" do
      waiting = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today + 1).id)
      send_to("/admin/tasks/#{waiting.id}/links", filter: "upcoming",
                                                  link: { kind: "blocks", other_id: waiting.id.to_s })

      expect(page).to have_css("#task-#{waiting.id}-link-other-id-error")
    end

    it "comes back to Today when it was added there" do
      link_from_today = { filter: "today", origin: "today", link: { kind: "blocks", other_id: other.id.to_s } }
      send_to("/admin/tasks/#{task.id}/links", **link_from_today)

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin"))
    end

    it "answers 404 for a task that isn't there" do
      send_to("/admin/tasks/0/links", filter: "next", link: { kind: "blocks", other_id: other.id.to_s })

      expect(last_response.status).to eq(404)
    end

    describe "a second link between the same two tasks" do
      before do
        create(:task_link, from_task_id: other.id, to_task_id: task.id, type: "relates")
        link
      end

      it "answers 422" do
        expect(last_response.status).to eq(422)
      end

      it "says the two are already linked" do
        expect(page.find("#task-#{task.id}-link-other-id-error").text)
          .to eq(i18n.t("ui.components.tasks.field_error.other_id.taken"))
      end

      it "leaves the editor open with the type that was picked", :aggregate_failures do
        expect(page).to have_css("#task-#{task.id}-edit[checked]")
        expect(page.find("#task-#{task.id}-link-kind option[selected]").value).to eq("blocks")
      end

      it "writes nothing" do
        expect(links.to_a.size).to eq(1)
      end
    end

    describe "a link to the task itself" do
      before { link(other_id: task.id) }

      it "answers 422" do
        expect(last_response.status).to eq(422)
      end

      it "says a task cannot link to itself" do
        expect(page.find("#task-#{task.id}-link-other-id-error").text)
          .to eq(i18n.t("ui.components.tasks.field_error.other_id.self"))
      end

      it "points the field at the error" do
        expect(page.find("#task-#{task.id}-link-other-id")["aria-describedby"])
          .to eq("task-#{task.id}-link-other-id-error")
      end
    end

    it "refuses a type outside the four" do
      link(kind: "follows")

      expect(page.find("#task-#{task.id}-link-kind-error").text)
        .to eq(i18n.t("ui.components.tasks.field_error.kind.format"))
    end

    it "says the task is gone when it no longer is there" do
      link(other_id: 999_999)

      expect(page.find("#task-#{task.id}-link-other-id-error").text)
        .to eq(i18n.t("ui.components.tasks.field_error.other_id.missing"))
    end
  end

  describe "removing a link" do
    before do
      sign_in_to_admin
      create(:task_link, from_task_id: other.id, to_task_id: task.id)
    end

    def unlink(id = task.id, other_id = other.id)
      send_to("/admin/tasks/#{id}/links/#{other_id}/delete", filter: "next")
    end

    it "offers a remove on each link in the editor" do
      get "/admin/tasks", filter: "next"

      expect(row("Ship the links"))
        .to have_css(".task-link-row form[action='/admin/tasks/#{task.id}/links/#{other.id}/delete']")
    end

    it "clears it from both tasks" do
      unlink

      expect([repo.by_id(task.id).links, repo.by_id(other.id).links]).to all(be_empty)
    end

    it "clears it from the end it was not stored on" do
      unlink(other.id, task.id)

      expect(links.to_a).to be_empty
    end

    it "says so" do
      unlink
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: i18n.t("tasks_page.toasts.unlinked"))
    end

    it "comes back to the list that was open" do
      unlink

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=next"))
    end

    it "answers 404 for a link that isn't there" do
      unlink(task.id, create(:task).id)

      expect(last_response.status).to eq(404)
    end
  end

  describe "signed out" do
    it "adds no link" do
      post "/admin/tasks/#{task.id}/links", link: { kind: "blocks", other_id: other.id.to_s }

      expect(links.to_a).to be_empty
    end

    it "removes no link" do
      create(:task_link, from_task_id: task.id, to_task_id: other.id)
      post "/admin/tasks/#{task.id}/links/#{other.id}/delete"

      expect(links.to_a.size).to eq(1)
    end
  end
end
