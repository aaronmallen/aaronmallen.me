# frozen_string_literal: true

RSpec.describe "Admin task links", :frozen_clock, type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Tasks::Slice["repos.task_queries"] }
  let(:task) { create(:task, title: "Ship the links") }
  let(:other) { create(:task, title: "Write the migration") }

  def count(title, tone) = row(title).first(".task-meta .task-mark.#{tone}", minimum: 0)

  def find_label = "ui.components.tasks.link_finder.find"

  def find_link(query, id: task.id) = get("/admin/tasks/#{id}", filter: "next", link_q: query)

  def find_link_as(kind, query)
    send_to("/admin/tasks/#{task.id}/links", filter: "next", link_find: "1", link_q: query, link: { kind: })
  end

  def link(kind: "blocks", other_id: other.id)
    send_to("/admin/tasks/#{task.id}/links", filter: "next", link: { kind:, other_id: other_id.to_s })
  end

  def link_label(code) = i18n.t(["ui.components.tasks.link_row.labels", code].join("."))

  def links = Tasks::Slice["relations.task_links"]

  def row(title) = page.find(".task-title", exact_text: title).ancestor(".task")

  def send_to(path, **params)
    post path, { _csrf_token: admin_csrf_token, **params }
  end

  def targets = page.all(".task-link-target").map { it.find(".record-key").text }

  describe "the counts on a row" do
    before do
      sign_in_to_admin
      create(:task_link, from_task_id: task.id, to_task_id: other.id)
    end

    def blocked_by(count) = i18n.t("ui.components.tasks.meta.blocked_by", count:)

    def blocking(count) = i18n.t("ui.components.tasks.meta.blocking", count:)

    it "shows blocking on the task that blocks, after its comments", :aggregate_failures do
      create(:task_comment, task_id: task.id)
      get "/admin/tasks", filter: "next"

      expect(count("Ship the links", :sand).text).to eq(blocking(1))
      expect(count("Ship the links", :sand)).to have_css(".fa-arrow-right-long")
      expect(row("Ship the links")).to have_css(".task-mark:has(.fa-comment) + .task-mark.sand")
    end

    it "shows blocked by with a lock on the task that is blocked", :aggregate_failures do
      get "/admin/tasks", filter: "next"

      expect(count("Write the migration", :pink).text).to eq(blocked_by(1))
      expect(count("Write the migration", :pink)).to have_css(".fa-lock")
    end

    it "lists the related tasks, one per line, on hover" do
      create(:task_link, from_task_id: task.id, to_task_id: create(:task, title: "Run the migration").id)
      get "/admin/tasks", filter: "next"

      titles = count("Ship the links", :sand)["title"].split("\n")

      expect(titles).to contain_exactly("Write the migration", "Run the migration")
    end

    it "counts each open block" do
      create(:task_link, from_task_id: create(:task, title: "Run the migration").id, to_task_id: other.id)
      get "/admin/tasks", filter: "next"

      expect(count("Write the migration", :pink).text).to eq(blocked_by(2))
    end

    %w[duplicates relates parent].each do |type|
      it "shows no chip and no count for a #{type} link", :aggregate_failures do
        links.where(from_task_id: task.id).update(type:)
        get "/admin/tasks", filter: "next"

        expect(page).to have_no_css(".task-meta .task-link-label")
        expect(page).to have_no_css(".task-meta .task-mark.sand, .task-meta .task-mark.pink")
      end
    end

    it "still lists the link with its type and title on the task's page", :aggregate_failures do
      get "/admin/tasks/#{other.id}", filter: "next"

      expect(page.find(".task-link-row .task-link-label").text).to eq(link_label(:blocked_by))
      expect(page.find(".task-link-row").find(".task-link-title").text).to eq("Ship the links")
    end

    it "shows no count on a task with no links" do
      create(:task, title: "Alone")
      get "/admin/tasks", filter: "next"

      expect(row("Alone")).to have_no_css(".task-meta .task-mark")
    end
  end

  describe "the blocked by count" do
    before do
      sign_in_to_admin
      create(:task_link, from_task_id: other.id, to_task_id: task.id)
    end

    def blocking?(title) = row(title).has_css?(".task-meta .task-mark.sand")

    def pill?(title)
      row(title).has_css?(".task-meta .task-mark.pink", text: i18n.t("ui.components.tasks.meta.blocked_by", count: 1))
    end

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

    it "hides blocking once the blocked task is canceled" do
      send_to("/admin/tasks/#{task.id}/cancel", filter: "next")
      get "/admin/tasks", filter: "next"

      expect(blocking?("Write the migration")).to be(false)
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

    describe "by label" do
      def in_project(**) = create(:task, project_id: Projects::Slice["relations.projects"].dataset.get(:id), **)

      def renumber(task, number) = Tasks::Slice["relations.tasks"].dataset.where(id: task.id).update(number:)

      before do
        create(:project, name: "Podcast")
        in_project(title: "Record the intro")
        in_project(title: "Edit the intro")
      end

      it "lists every task with the number, in a project or none, by n or #n", :aggregate_failures do
        find_link("2")
        expect(targets).to contain_exactly("2", "POD-2")

        find_link("#2")
        expect(targets).to contain_exactly("2", "POD-2")
      end

      it "finds a task by KEY-n in any case, with or without #" do
        %w[POD-2 pod-2 #POD-2].each do |query|
          find_link(query)
          expect(targets).to eq(["POD-2"])
        end
      end

      it "finds no task whose label only starts with the query" do
        renumber(in_project(title: "Mix the outro"), 23)
        find_link("POD-2")

        expect(targets).to eq(["POD-2"])
      end

      it "finds no task by its database id" do
        loose = create(:task, title: "Loose")
        Tasks::Slice["relations.tasks"].dataset.where(id: loose.id).update(id: 900_001)
        find_link("900001")

        expect(targets).to be_empty
      end

      it "lists label matches ahead of title matches" do
        create(:task, title: "Plan 2.0")
        find_link("2")

        expect([targets.size, targets.last]).to eq([3, "3"])
      end
    end

    it "finds a task by its title" do
      find_link("migration")

      expect(targets).to eq([other.number.to_s])
    end

    it "leaves the task itself out" do
      find_link("##{task.number}")

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

      expect(targets).to eq([other.number.to_s, canceled.number.to_s])
    end

    it "says when nothing matches" do
      find_link("nothing like it")

      expect(page).to have_css(".task-link-editor", text: i18n.t("ui.components.tasks.link_finder.no_match"))
    end

    it "keeps the query in the field" do
      find_link("migration")

      expect(page.find("#task-#{task.id}-link-other-id").value).to eq("migration")
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
      get "/admin/tasks/#{waiting.id}", filter: "upcoming", link_q: "migration"

      expect(page).to have_css("#task-#{waiting.id}-link-other-id")
      expect(targets).to eq([other.number.to_s])
    end

    it "sends the find on the upcoming tab back to that tab" do
      waiting = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today + 1).id)
      get "/admin/tasks/#{waiting.id}", filter: "upcoming"

      form = page.find("#task-#{waiting.id}-link-other-id")["form"]

      expect(page.find("form##{form} input[name='filter']", visible: :all).value).to eq("upcoming")
    end

    it "sends the find and the type from the form that adds the link", :aggregate_failures do
      get "/admin/tasks/#{task.id}", filter: "next"
      form = "task-#{task.id}-link-add"

      expect(page).to have_css("input#task-#{task.id}-link-other-id[form='#{form}'][name='link_q']")
      expect(page).to have_css("button[form='#{form}'][name='link_find']", text: i18n.t(find_label))
      expect(page).to have_css("select[form='#{form}'][name='link[kind]']")
    end

    describe "a find with a type picked" do
      def found = "/admin/tasks/#{task.id}?filter=next&origin=tasks&link_kind=blocked_by&link_q=migration"

      before { find_link_as("blocked_by", " migration ") }

      it "comes back to the task's page with the query and the type" do
        expect(last_response).to be_redirect.and have_attributes(location: end_with(found))
      end

      it "keeps the type picked", :aggregate_failures do
        follow_redirect!

        expect(page.find("#task-#{task.id}-link-kind option[selected]").value).to eq("blocked_by")
        expect(targets).to eq([other.number.to_s])
      end

      it "writes nothing" do
        expect(links.to_a).to be_empty
      end

      it "adds the link with that type from a match" do
        follow_redirect!
        link(kind: page.find("#task-#{task.id}-link-kind option[selected]").value)

        expect(links.to_a.map { it.to_h.values_at(:from_task_id, :to_task_id, :type) })
          .to eq([[other.id, task.id, "blocks"]])
      end
    end

    it "falls back to the first type for one outside the four" do
      get "/admin/tasks/#{task.id}", filter: "next", link_q: "migration", link_kind: "follows"

      expect(page).to have_no_css("#task-#{task.id}-link-kind option[selected]")
    end

    it "offers the four types" do
      get "/admin/tasks/#{task.id}", filter: "next"
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

    it "shows the count once the page comes back" do
      link
      follow_redirect!

      expect(count("Ship the links", :sand).text).to eq(i18n.t("ui.components.tasks.meta.blocking", count: 1))
    end

    it "shows a waiting task's page with the error, keeping the upcoming tab", :aggregate_failures do
      waiting = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today + 1).id)
      send_to("/admin/tasks/#{waiting.id}/links", filter: "upcoming",
                                                  link: { kind: "blocks", other_id: waiting.id.to_s })

      expect(page).to have_css("#task-#{waiting.id}-link-other-id-error")
      expect(page.find(".task-drawer-foot a[data-task-close]")["href"]).to eq("/admin/tasks?filter=upcoming")
    end

    it "comes back to Today when it was added there" do
      link_from_today = { filter: "today", origin: "today", link: { kind: "blocks", other_id: other.id.to_s } }
      send_to("/admin/tasks/#{task.id}/links", **link_from_today)

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin"))
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

      it "shows the task's page with the type that was picked", :aggregate_failures do
        expect(page).to have_css("[data-task-read='#{task.id}']")
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

    it "says the task is gone when its ID runs past the integer range", :aggregate_failures do
      link(other_id: 2**31)

      expect(last_response.status).to eq(422)
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

    it "offers a remove on each link on the task's page" do
      get "/admin/tasks/#{task.id}", filter: "next"

      expect(page)
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
end
