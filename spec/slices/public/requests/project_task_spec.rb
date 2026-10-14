# frozen_string_literal: true

RSpec.describe "Project task page", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:project) { create(:project, name: "Doing It", board_published: true) }
  let(:hush) { create(:project, :private, name: "Hush", board_published: true) }

  def link(task, project)
    Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "project", other_id: project.id })
    task
  end

  def visit_related(*others, type: "relates")
    task = link(create(:task), project)
    others.each { create(:task_link, from_task_id: task.id, to_task_id: it.id, type:) }
    visit_task(task)
  end

  def visit_task(task, slug = "doing-it") = get("/projects/#{slug}/tasks/#{task.id}")

  describe "a task on a published board" do
    it "shows the number and title under an h1", :aggregate_failures do
      task = link(create(:task, title: "Ship it"), project)
      visit_task(task)

      expect(last_response).to be_ok
      expect(page).to have_css("header.hd > .kicker", exact_text: "Task ##{task.id}")
      expect(page).to have_css("h1", exact_text: "Ship it")
    end

    it "lets caches keep it for five minutes" do
      visit_task(link(create(:task), project))

      expect(last_response.headers["Cache-Control"]).to eq("public, max-age=0, s-maxage=300")
    end

    it "links back to the board" do
      visit_task(link(create(:task), project))

      expect(page).to have_link("Doing It board", href: "/projects/doing-it")
    end

    it "shows the status and column", :aggregate_failures do
      visit_task(link(create(:task, stage: "ready"), project))

      expect(page).to have_css(".task-facts dt + dd", exact_text: "open")
      expect(page).to have_css(".task-facts dd", exact_text: "ready")
    end

    it "shows the day a task was done" do
      visit_task(link(create(:task, :done, completed_at: Time.utc(2026, 10, 3, 18)), project))

      expect(page.all(".task-facts > *").map(&:text)).to eq(["Status", "done", "Column", "done", "Done", "Oct 3, 2026"])
    end

    it "shows the day a task was canceled" do
      visit_task(link(create(:task, :canceled, completed_at: Time.utc(2026, 10, 4, 18)), project))

      expect(page).to have_css(".task-facts dt", exact_text: "Canceled")
    end

    it "links the source issue" do
      task = link(create(:task), project)
      create(:task_source, task:, remote_id: "I_42")
      visit_task(task)

      expect(page).to have_link("aaronmallen/aaronmallen.me#42", href: "https://github.com/aaronmallen/aaronmallen.me/issues/42")
    end

    it "renders the notes sanitized", :aggregate_failures do
      note = "**bold** <script>alert(1)</script><a href=\"javascript:alert(1)\" onclick=\"x()\">bad</a>"
      visit_task(link(create(:task, note:), project))

      expect(page).to have_css(".task-section .post-body strong", exact_text: "bold")
      expect(last_response.body).not_to match(/<script>alert|javascript:alert|onclick/)
    end

    it "shows the comments oldest first" do
      task = link(create(:task), project)
      create(:task_comment, task:, body: "first", created_at: Time.now - 60)
      create(:task_comment, task:, body: "second")
      visit_task(task)

      expect(page.all(".task-comment .post-body").map { it.text.strip }).to eq(%w[first second])
    end

    it "names a synced comment's author" do
      task = link(create(:task), project)
      create(:task_comment, :synced, task:)
      visit_task(task)

      expect(page).to have_css(".task-comment-head", text: "octocat")
    end

    it "shows no tags, time or work hours", :aggregate_failures do
      tag = create(:tag, name: "private-tag")
      task = link(create(:task, tags: [tag.name], worked_seconds: 3600), project)
      visit_task(task)

      expect(page).to have_no_text("private-tag")
      expect(page.all(".task-facts dt").map(&:text)).to eq(%w[Status Column])
    end

    it "names each related task on a published board by how it relates", :aggregate_failures do
      blocked = link(create(:task, title: "Blocked"), project)
      visit_related(blocked, type: "blocks")

      expect(page).to have_css(".task-related li", text: "blocks ##{blocked.id} Blocked")
      expect(page).to have_link("##{blocked.id} Blocked", href: "/projects/doing-it/tasks/#{blocked.id}")
    end

    it "links a related task on another published board to that board" do
      other = link(create(:task, title: "Elsewhere"), create(:project, name: "Other", board_published: true))
      visit_related(other)

      expect(page).to have_link("##{other.id} Elsewhere", href: "/projects/other/tasks/#{other.id}")
    end

    it "leaves out a related task on no published board of a public project", :aggregate_failures do
      hidden = link(create(:task, title: "Private secret"), hush)
      unpublished = link(create(:task, title: "Unpublished secret"), create(:project, name: "Plain"))
      visit_related(create(:task, title: "Loose secret"), hidden, unpublished)

      expect(page).to have_no_text("secret")
      expect(page).to have_no_css(".task-related")
    end
  end

  describe "a task that is not public" do
    it "answers 404 for a task on no board" do
      visit_task(create(:task))

      expect(last_response.status).to eq(404)
    end

    it "answers 404 for a task on another project's board" do
      project
      other = link(create(:task), create(:project, name: "Other", board_published: true))
      visit_task(other)

      expect(last_response.status).to eq(404)
    end

    it "answers 404 when the project is private" do
      task = link(create(:task), hush)
      visit_task(task, "hush")

      expect(last_response.status).to eq(404)
    end

    it "answers 404 when the board is not published" do
      task = link(create(:task), create(:project, name: "Plain"))
      visit_task(task, "plain")

      expect(last_response.status).to eq(404)
    end

    it "answers 404 for a number that is not a task id", :aggregate_failures do
      project
      get "/projects/doing-it/tasks/abc"
      expect(last_response.status).to eq(404)

      get "/projects/doing-it/tasks/99999999999"
      expect(last_response.status).to eq(404)
    end

    it "keeps caches from holding it" do
      visit_task(create(:task))

      expect(last_response.headers["Cache-Control"].to_s).not_to include("s-maxage")
    end
  end
end
