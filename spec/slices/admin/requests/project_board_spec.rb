# frozen_string_literal: true

RSpec.describe "Admin project board", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:project) do
    create(:project, name: "blog", tagline: "My site", repo: "aaronmallen/blog", url: "https://aaronmallen.me")
  end
  let(:tasks) { Tasks::Slice["repos.task_queries"] }

  def arrows(name) = column(name).all(".hov form[data-morph] input[name=to]", visible: :all).map(&:value)

  def bulk(ids, to, **)
    post("/admin/projects/#{project.id}/tasks/bulk", { _csrf_token: admin_csrf_token, act: "move", ids:, to:, ** })
  end

  def column(name) = page.find("section.kcol.k-#{name}")

  def link(task) = Tasks::Slice["operations.set_task_project"].call(task.id, project.id)

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

      it "offers a Select button for the board's bulk bar with bulk mode off", :aggregate_failures do
        expect(page).to have_css("button[data-bulk-toggle='board-bulk'][aria-pressed='false']")
        expect(page).to have_css("form#board-bulk[data-bulk-off]")
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

    describe "a card's key" do
      def keys = column("backlog").all(".record-key").map(&:text)

      def rekey(key)
        fields = { name: "blog", repo: "aaronmallen/blog", visibility: "public", key: }
        post "/admin/projects/#{project.id}", _csrf_token: admin_csrf_token, project: fields
      end

      before do
        linked(title: "Plan it")
        linked(title: "Write it")
      end

      it "joins the project key to the task's number" do
        get "/admin/projects/#{project.id}"

        expect(keys).to match_array(%w[BLO-1 BLO-2])
      end

      it "shows the new key once the project's key changes" do
        rekey("WEB")
        get "/admin/projects/#{project.id}"

        expect(keys).to match_array(%w[WEB-1 WEB-2])
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

      it "copies the task's label" do
        expect(page).to have_css("[data-copy='BLO-1']", visible: :all)
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

      it "puts a card moved into an open column first in it" do
        linked(stage: "ready", title: "Waiting")
        move(linked(title: "Plan it"), "ready")
        get "/admin/projects/#{project.id}"

        expect(titles("ready")).to eq(["Plan it", "Waiting"])
      end

      it "puts a card moved into in progress first there, ahead of tasks in other lists" do
        linked(:in_progress, :in_sprint, title: "Doing")
        move(linked(:someday, title: "Plan it"), "in_progress")
        get "/admin/projects/#{project.id}"

        expect(titles("in_progress")).to eq(["Plan it", "Doing"])
      end

      it "puts a reopened card first in its open column" do
        linked(title: "Waiting")
        move(linked(:done, title: "Ship it"), "backlog")
        get "/admin/projects/#{project.id}"

        expect(titles("backlog")).to eq(["Ship it", "Waiting"])
      end

      it "returns to the board with a toast", :aggregate_failures do
        task = linked
        move(task, "ready")

        expect(last_response.location).to end_with("/admin/projects/#{project.id}")
        follow_redirect!
        expect(toast).to eq("Moved BLO-1 to ready")
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

    describe "a full column" do
      def days_ago(days) = now - (days * 86_400)

      def more(name) = column(name).find("form[data-autosubmit][method='get']")

      def more_fields(name) = more(name).all("input[type=hidden]", visible: :all).to_h { [it[:name], it.value] }

      before do
        change_board_setting(:column_size, to: 2)
        3.times { linked(title: "Plan #{it}") }
        3.times { linked(stage: "ready", title: "Ready #{it}") }
      end

      it "shows the cap and offers the rest", :aggregate_failures do
        get "/admin/projects/#{project.id}"

        expect(titles("backlog").size).to eq(2)
        expect(more("backlog")).to have_button("Load more · 1 left")
        expect(more("backlog")[:action]).to eq("/admin/projects/#{project.id}")
      end

      it "grows only that column" do
        get "/admin/projects/#{project.id}"

        expect(more_fields("backlog")).to eq("backlog" => "4")
      end

      it "shows the grown column whole and leaves the others capped", :aggregate_failures do
        get "/admin/projects/#{project.id}", backlog: 4

        expect([titles("backlog").size, titles("ready").size]).to eq([3, 2])
        expect(column("backlog")).to have_no_css("form[data-autosubmit]")
        expect(more_fields("ready")).to eq("backlog" => "4", "ready" => "4")
      end

      it "never shows fewer than the cap" do
        get "/admin/projects/#{project.id}", backlog: 1

        expect(titles("backlog").size).to eq(2)
      end

      it "counts every task in the heads and the facts bar", :aggregate_failures do
        get "/admin/projects/#{project.id}"

        expect(page.all(".kcol-count").map(&:text)).to eq(%w[3 3 0 0 0])
        expect(page).to have_css(".kb-meta", text: "6 open · 6 total")
      end

      it "leaves old closed tasks out of the count and Load More", :aggregate_failures do
        2.times { linked(:done, completed_at: days_ago(1)) }
        linked(:done, completed_at: days_ago(30))
        get "/admin/projects/#{project.id}"

        expect(column("done").find(".kcol-count").text).to eq("2")
        expect(column("done")).to have_no_css("form[data-autosubmit]")
      end

      it "shows the latest closed tasks first" do
        linked(:done, title: "Oldest", completed_at: days_ago(3))
        linked(:done, title: "Newest", completed_at: days_ago(1))
        linked(:done, title: "Middle", completed_at: days_ago(2))
        get "/admin/projects/#{project.id}"

        expect(titles("done")).to eq(%w[Newest Middle])
      end

      it "returns a card move and the bulk bar to the grown board", :aggregate_failures do
        get "/admin/projects/#{project.id}", backlog: 4
        grown = "/admin/projects/#{project.id}?backlog=4"

        expect(column("backlog").first(".hov input[name=return_to]", visible: :all).value).to eq(grown)
        expect(page.find("input[name=return_to][form=board-bulk]", visible: :all).value).to eq(grown)
      end

      it "goes back to the grown board after a card move" do
        move(linked, "ready", return_to: "/admin/projects/#{project.id}?backlog=4")

        expect(last_response.location).to end_with("/admin/projects/#{project.id}?backlog=4")
      end

      it "goes back to the grown board after a bulk move" do
        bulk([linked.id], "done", return_to: "/admin/projects/#{project.id}?ready=4")

        expect(last_response.location).to end_with("/admin/projects/#{project.id}?ready=4")
      end
    end

    describe "a closed task's age" do
      def board = Blog::Types::TaskColumn.values.flat_map { titles(it) }

      def days_ago(days) = now - (days * 86_400)

      it "drops a task closed 14 days ago or more", :aggregate_failures do
        linked(:done, title: "Shipped", completed_at: days_ago(14))
        linked(:canceled, title: "Dropped", completed_at: days_ago(30))
        get "/admin/projects/#{project.id}"

        expect(board).to be_empty
        expect(page).to have_css(".kb-meta", text: "0 open · 0 total")
      end

      it "keeps a task closed less than 14 days ago", :aggregate_failures do
        linked(:done, title: "Shipped", completed_at: days_ago(14) + 60)
        linked(:canceled, title: "Dropped", completed_at: days_ago(1))
        get "/admin/projects/#{project.id}"

        expect(titles("done")).to eq(["Shipped"])
        expect(titles("canceled")).to eq(["Dropped"])
      end

      it "counts the days from the last close" do
        task = linked(:done, title: "Shipped again", completed_at: days_ago(30))
        move(task, "backlog")
        move(task, "done")
        get "/admin/projects/#{project.id}"

        expect(titles("done")).to eq(["Shipped again"])
      end

      it "reads the days from settings" do
        change_board_setting(:closed_days, to: 1)
        linked(:done, title: "Shipped", completed_at: days_ago(2))
        get "/admin/projects/#{project.id}"

        expect(board).to be_empty
      end

      it "keeps a task off the board in the task list and MCP", :aggregate_failures do
        linked(:done, title: "Shipped", completed_at: days_ago(30))
        get "/admin/tasks", filter: "completed"

        expect(page.all(".task-title").map(&:text)).to eq(["Shipped"])
        expect(mcp_answer("list_tasks", statuses: %w[done]).fetch("tasks").map { trusted(it.fetch("title")) })
          .to eq(["Shipped"])
      end
    end
  end
end
