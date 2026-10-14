# frozen_string_literal: true

RSpec.describe "Admin project board", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:project) do
    create(:project, name: "blog", tagline: "My site", repo: "aaronmallen/blog", url: "https://aaronmallen.me")
  end
  let(:tasks) { Tasks::Slice["repos.task_queries"] }

  def arrows(name) = column(name).all(".hov form[data-morph] input[name=to]", visible: :all).map(&:value)

  def bulk(ids, to)
    post("/admin/projects/#{project.id}/tasks/bulk", { _csrf_token: admin_csrf_token, act: "move", ids:, to: })
  end

  def column(name) = page.find("section.kcol.k-#{name}")

  def link(task) = Links::Slice["repos.record_link_mutations"].link(["task", task.id], ["project", project.id])

  def linked(*traits, **attributes) = create(:task, *traits, **attributes).tap { link(it) }

  def move(task, to, **)
    post("/admin/projects/#{project.id}/tasks/#{task.id}/move", { _csrf_token: admin_csrf_token, to:, ** })
  end

  def titles(name) = column(name).all(".kc-title").map(&:text)

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all)

  describe "signed out" do
    it "sends me to sign in" do
      get "/admin/projects/#{project.id}"

      expect(last_response).to be_redirect
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "offers the board first in the project menu" do
      get "/admin/projects/#{project.id}/menu"

      expect(page.first("a.ctx-item", visible: :all)[:href]).to eq("/admin/projects/#{project.id}")
    end

    it "links the editor back to the board" do
      get "/admin/projects/#{project.id}/edit"

      expect(page).to have_link("blog board", href: "/admin/projects/#{project.id}", class: "editor-back")
    end

    it "answers 404 for a project that is gone" do
      get "/admin/projects/0"

      expect(last_response.status).to eq(404)
    end

    it "says the board is published for a public project with the flag on" do
      get "/admin/projects/#{create(:project, board_published: true).id}"

      expect(page).to have_css(".kb-meta .kb-published", text: "board published")
    end

    it "keeps a private project's board private with the flag on" do
      get "/admin/projects/#{create(:project, :private, board_published: true).id}"

      expect(page).to have_css(".kb-meta", text: "board is private")
    end

    describe "the board" do
      before do
        linked(title: "Plan it")
        linked(title: "Ready it", stage: "ready")
        linked(:in_progress, title: "Do it")
        linked(:done, title: "Ship it")
        linked(:canceled, title: "Drop it")
        create(:task, title: "Elsewhere")
        get "/admin/projects/#{project.id}"
      end

      it "shows every linked task in its column" do
        expect(Blog::Types::TaskColumn.values.map { titles(it) })
          .to eq([["Plan it"], ["Ready it"], ["Do it"], ["Ship it"], ["Drop it"]])
      end

      it "counts each column" do
        expect(page.all(".kcol-count").map(&:text)).to eq(%w[1 1 1 1 1])
      end

      it "heads the board with the name and tagline", :aggregate_failures do
        expect(page).to have_css(".page-head-title", text: "blog")
        expect(page).to have_css(".page-head-sub", text: "My site")
      end

      it "links the repo and the site", :aggregate_failures do
        expect(page).to have_link("aaronmallen/blog", href: "https://github.com/aaronmallen/blog")
        expect(page).to have_link("aaronmallen.me", href: "https://aaronmallen.me")
      end

      it "counts the open and total tasks" do
        expect(page).to have_css(".kb-meta", text: "3 open · 5 total")
      end

      it "says the board is private until it is published" do
        expect(page).to have_css(".kb-meta", text: "board is private")
      end

      it "links to the editor" do
        expect(page).to have_link("Edit Project", href: "/admin/projects/#{project.id}/edit")
      end

      it "opens a card's task in the drawer" do
        expect(column("backlog")).to have_css("a.kc-title[data-task-open][href^='/admin/tasks/']", text: "Plan it")
      end

      it "gives a card arrows to the columns beside it, posted by fetch and morph" do
        expect(arrows("ready")).to eq(%w[backlog in_progress])
      end

      it "gives the end columns one arrow each", :aggregate_failures do
        expect(arrows("backlog")).to eq(%w[ready])
        expect(arrows("canceled")).to eq(%w[done])
      end

      it "offers a Select button for the board's bulk bar" do
        expect(page).to have_css("button[data-bulk-toggle='board-bulk']", visible: :all)
      end

      it "gives each card a box that joins the bar" do
        expect(page.all(".kc input[type='checkbox'][name='ids[]'][form='board-bulk']").size).to eq(5)
      end

      it "offers each column as a target in the bar", :aggregate_failures do
        expect(page).to have_css("form#board-bulk[action='/admin/projects/#{project.id}/tasks/bulk']")
        expect(page.all("form#board-bulk select[name='to'] option").map(&:value))
          .to eq(["", "backlog", "ready", "in_progress", "done", "canceled"])
      end

      it "fetches the card menu with the board's project" do
        expect(column("backlog")).to have_css(".kc[data-menu$='/menu?project=#{project.id}']")
      end
    end

    describe "the card menu" do
      let(:task) { linked(title: "Plan it") }

      before { get "/admin/tasks/#{task.id}/menu", project: project.id, return_to: "/admin/projects/#{project.id}" }

      it "offers every column, with the card's own disabled", :aggregate_failures do
        forms = page.all("form[action='/admin/projects/#{project.id}/tasks/#{task.id}/move']", visible: :all)

        expect(forms.map { it.find("input[name=to]", visible: :all).value })
          .to eq(%w[backlog ready in_progress done canceled])
        expect(forms.first).to have_css("button[disabled]", visible: :all)
      end

      it "returns to the board" do
        form = page.first("form[action='/admin/projects/#{project.id}/tasks/#{task.id}/move']", visible: :all)

        expect(form.find("input[name=return_to]", visible: :all).value).to eq("/admin/projects/#{project.id}")
      end
    end

    it "leaves the board column out of a task menu opened anywhere else" do
      get "/admin/tasks/#{create(:task).id}/menu"

      expect(page).to have_no_css(".ctx-label", text: "Board column", visible: :all)
    end

    describe "moving ticked cards" do
      let(:open) { linked }
      let(:done) { linked(:done) }

      before { bulk([open.id, done.id], "in_progress") }

      it "moves every ticked task to the column" do
        expect([open, done].map { tasks.by_id(it.id).status }).to eq(%w[in_progress in_progress])
      end

      it "returns to the board with a toast", :aggregate_failures do
        expect(last_response.location).to end_with("/admin/projects/#{project.id}")
        follow_redirect!
        expect(toast).to eq("Moved 2 tasks to in progress")
      end
    end

    describe "moving ticked cards with one that is gone" do
      let(:task) { linked }
      let(:missing) { create(:task).id.tap { Tasks::Slice["repos.task_mutations"].delete(it) } }

      before { bulk([task.id, missing], "done") }

      it "changes nothing" do
        expect(tasks.by_id(task.id).status).to eq("open")
      end

      it "names the task that is gone" do
        follow_redirect!

        expect(toast).to eq("Nothing changed · ##{missing} is gone")
      end
    end

    it "asks for a column before it moves ticked cards", :aggregate_failures do
      task = linked
      bulk([task.id], "")

      expect(tasks.by_id(task.id).status).to eq("open")
      follow_redirect!
      expect(toast).to eq("Pick a column first")
    end

    describe "moving a card" do
      it "moves an open card to ready and changes only its stage", :aggregate_failures do
        task = linked(title: "Plan it")
        move(task, "ready")
        found = tasks.by_id(task.id)

        expect([found.stage, found.status, found.list]).to eq(%w[ready open next])
        expect(tasks.timeline(task.id)).to be_empty
      end

      it "moves a ready card back to backlog" do
        task = linked(stage: "ready")
        move(task, "backlog")

        expect(tasks.by_id(task.id).stage).to eq("backlog")
      end

      it "starts a card moved to in progress", :aggregate_failures do
        task = linked
        move(task, "in_progress")
        found = tasks.by_id(task.id)

        expect(found.status).to eq("in_progress")
        expect(found.running_session).not_to be_nil
      end

      it "completes a card moved to done" do
        task = linked(:in_progress)
        move(task, "done")

        expect(tasks.by_id(task.id).status).to eq("done")
      end

      it "cancels a card moved to canceled" do
        task = linked
        move(task, "canceled")

        expect(tasks.by_id(task.id).status).to eq("canceled")
      end

      it "cancels a done card moved to canceled" do
        task = linked(:done)
        move(task, "canceled")

        expect(tasks.by_id(task.id).status).to eq("canceled")
      end

      it "reopens a done card moved to ready and sets its stage" do
        task = linked(:done)
        move(task, "ready")
        found = tasks.by_id(task.id)

        expect([found.status, found.stage, found.completed_at]).to eq(["open", "ready", nil])
      end

      it "reopens a card in progress moved to backlog", :aggregate_failures do
        task = linked(:in_progress, stage: "ready")
        move(task, "backlog")
        found = tasks.by_id(task.id)

        expect([found.status, found.stage]).to eq(%w[open backlog])
      end

      it "returns to the board with a toast", :aggregate_failures do
        task = linked
        move(task, "ready")

        expect(last_response.location).to end_with("/admin/projects/#{project.id}")
        follow_redirect!
        expect(toast).to eq("Moved ##{task.id} to ready")
      end

      it "returns to the page the menu opened on" do
        move(linked, "ready", return_to: "/admin/tasks")

        expect(last_response.location).to end_with("/admin/tasks")
      end

      it "refuses a column it doesn't know" do
        move(linked, "someday")

        expect(last_response.status).to eq(422)
      end

      it "answers 404 for a task that is gone" do
        post "/admin/projects/#{project.id}/tasks/0/move", _csrf_token: admin_csrf_token, to: "ready"

        expect(last_response.status).to eq(404)
      end
    end
  end
end
