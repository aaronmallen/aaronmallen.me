# frozen_string_literal: true

RSpec.describe "Admin task page", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:task) { create(:task, title: "Ship the read page", note: "say **why** it matters") }
  let(:other) { create(:task, title: "Write the migration") }

  def body = page.find(".task-body")

  def facts = page.all(".task-fact").to_h { [it.find("dt").text, it.find("dd").text] }

  def label(key, **) = i18n.t(key, scope: "ui.views.tasks.show", **)

  def left_yesterday = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today - 1).id)

  def lose_the_roll
    failing = Tasks::Slice["repos.sprint_repo"]
    allow(failing).to receive(:by_id).and_return(nil)
    replace_component("repos.sprint_repo", failing)
  end

  def read(record = task, **) = get("/admin/tasks/#{record.id}", **)

  def read_note(note) = read(create(:task, note:))

  def send_to(path, **params)
    post path, { _csrf_token: admin_csrf_token, **params }
  end

  def stamp(time) = Blog::TimeZone.local(time).strftime("%b %-d, %Y, %H:%M")

  describe "signed out" do
    it "redirects to sign-in" do
      read

      expect(last_response.location).to end_with("/admin/sign-in")
    end

    it "sends neither the title nor the note", :aggregate_failures do
      read

      expect(last_response.body).not_to include("Ship the read page")
      expect(last_response.body).not_to include("it matters")
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "answers 404 for a task that isn't there" do
      get "/admin/tasks/404404"

      expect(last_response.status).to eq(404)
    end

    it "heads the page with the title" do
      read

      expect(page).to have_css(".page-head h1", exact_text: "Ship the read page")
    end

    it "titles the tab with the task" do
      read

      expect(page).to have_title("Ship the read page | Admin | #{Blog::Owner.full_name}")
    end

    it "draws the key as a badge that copies it" do
      read

      expect(page).to have_css(".task-read-meta button.task-key[data-task-key='##{task.id}']", text: "##{task.id}")
    end

    {
      open: [],
      in_progress: [:in_progress],
      done: [:done],
      canceled: [:canceled],
    }.each do |status, traits|
      it "shows the #{status} status" do
        read(create(:task, *traits))

        expect(page).to have_css(".task-read-meta .pill", text: label("statuses.#{status}"))
      end
    end

    it "shows the tags" do
      read(create(:task, tags: %w[site admin]))

      expect(page.all(".task-read-meta .task-tag").map(&:text)).to contain_exactly("#site", "#admin")
    end

    it "shows the GitHub issue it came from" do
      source = create(:task_source, task:, url: "https://github.com/aaronmallen/aaronmallen.me/issues/42")
      read

      expect(page).to have_link("aaronmallen/aaronmallen.me#42", href: source.url)
    end

    it "shows the Linear issue it came from" do
      url = "https://linear.app/acme/issue/ABC-123/ship-the-release"
      create(:task_source, task:, provider: "linear", remote_id: "lin-1", url:)
      read

      expect(page).to have_link("ABC-123", href: url)
    end

    it "shows no source on a task typed in the admin" do
      read

      expect(page).to have_no_css(".task-source")
    end

    describe "the dates" do
      it "shows when it was created and last changed", :aggregate_failures do
        read

        expect(facts[label(:created)]).to eq(stamp(task.created_at))
        expect(facts[label(:updated)]).to eq(stamp(task.updated_at))
      end

      it "shows when it was completed" do
        done = create(:task, :done)
        read(done)

        expect(facts[label(:completed)]).to eq(stamp(done.completed_at))
      end

      it "leaves completed off an open task" do
        read

        expect(facts).not_to have_key(label(:completed))
      end

      it "shows the sprint day it is set for" do
        day = Blog::TimeZone.today + 2
        read(create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: day).id))

        expect(facts[label(:sprint)]).to eq(day.strftime("%b %-d, %Y"))
      end

      it "rolls a task left in yesterday's sprint into today's before it shows the day" do
        read(left_yesterday)

        expect(facts[label(:sprint)]).to eq(Blog::TimeZone.today.strftime("%b %-d, %Y"))
      end

      it "answers with a server error when the day's sprint cannot be rolled" do
        task = left_yesterday
        lose_the_roll
        read(task)

        expect(last_response.status).to eq(500)
      end

      it "says when it is set for no sprint day" do
        read

        expect(facts[label(:sprint)]).to eq(label(:unscheduled))
      end

      it "shows how many times it carried over" do
        read(create(:task, :carried))

        expect(facts[label(:carried)]).to eq(label(:carried_count, count: 2))
      end
    end

    describe "the note" do
      it "renders as markdown" do
        read_note("- one\n- two")

        expect(body.all("li").map(&:text)).to eq(%w[one two])
      end

      it "shows no empty block on a task with no note" do
        read_note("")

        expect(page).to have_no_css(".task-body")
      end

      it "shows no empty block when nothing survives the cleaning" do
        read_note("<script>alert(1)</script>")

        expect(page).to have_no_css(".task-body")
      end

      it "keeps raw HTML", :aggregate_failures do
        read_note("<details><summary>More</summary>\n\nHidden <kbd>K</kbd><br><sub>s</sub></details>")

        expect(body).to have_css("details summary", text: "More")
        expect(body).to have_css("details kbd", text: "K", visible: :all)
        expect(body).to have_css("details br", visible: :all)
        expect(body).to have_css("details sub", text: "s", visible: :all)
      end

      it "keeps an image from https" do
        read_note('<img src="https://example.com/shot.png" alt="shot">')

        expect(body).to have_css("img[src='https://example.com/shot.png'][alt='shot']")
      end

      it "strips scripts and their content", :aggregate_failures do
        read_note("before\n\n<script>alert('owned')</script>\n\nafter")

        expect(body).to have_no_css("script", visible: :all)
        expect(body.text).not_to include("owned")
      end

      it "strips event handlers", :aggregate_failures do
        read_note('<b onclick="alert(1)" onmouseover="alert(2)">bold</b>')

        expect(body).to have_css("b", text: "bold")
        expect(body.find("b").native.attributes.keys).to be_empty
      end

      it "strips javascript: links from markdown and HTML alike", :aggregate_failures do
        read_note('[one](javascript:alert(1)) <a href="javascript:alert(2)">two</a> <a href="JaVaScRiPt:x">3</a>')

        expect(body.all("a").map(&:text)).to eq(%w[one two 3])
        expect(body).to have_no_css("a[href]")
      end

      it "keeps an https link" do
        read_note("[docs](https://hanamirb.org)")

        expect(body).to have_link("docs", href: "https://hanamirb.org")
      end

      it "strips a data: image" do
        read_note('<img src="data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=" alt="x">')

        expect(body).to have_no_css("img[src]")
      end

      it "strips a srcset, which skips the check on src" do
        read_note('<img src="https://example.com/a.png" srcset="data:image/png;base64,AA 1x" alt="x">')

        expect(body).to have_no_css("img[srcset]")
      end

      it "strips the elements that run or load code", :aggregate_failures do
        read_note(
          "<iframe src=\"https://example.com\"></iframe><object data=\"x\"></object><embed src=\"x\">" \
          "<svg onload=\"alert(1)\"></svg><form action=\"/admin/tasks\"><button>go</button></form><style>*{}</style>",
        )

        %w[iframe object embed svg form button style].each { expect(body).to have_no_css(it, visible: :all) }
      end

      it "strips class, id, style and tabindex", :aggregate_failures do
        read_note('<div class="fixed inset-0" id="task-dialog" style="color:red" tabindex="0" title="kept">x</div>')

        expect(body.find("div").native.attributes.keys).to eq(%w[title])
      end

      it "keeps a task list as disabled checkboxes", :aggregate_failures do
        read_note("- [x] done\n- [ ] not yet")

        expect(body.all("input[type='checkbox'][disabled]").size).to eq(2)
        expect(body).to have_css("input[type='checkbox'][checked]", count: 1)
      end

      it "strips every other input" do
        read_note('<input type="text" name="x"><input type="checkbox"><input type="hidden" value="y">')

        expect(body.all("input", visible: :all)).to be_empty
      end

      it "leaves the stored note as it was written" do
        note = "<script>alert(1)</script>"
        written = create(:task, note:)
        read(written)

        expect(repo.by_id(written.id).note).to eq(note)
      end
    end

    describe "the actions" do
      def action?(name, record = task) = page.has_css?("form[action='/admin/tasks/#{record.id}/#{name}']")

      it "offers start and cancel on an open task", :aggregate_failures do
        read

        expect(%w[start cancel complete stop reopen].map { action?(it) }).to eq([true, true, false, false, false])
      end

      it "offers complete, stop and cancel on a running task" do
        running = create(:task, :in_progress, :in_sprint)
        read(running)

        expect(%w[start cancel complete stop reopen].map { action?(it, running) })
          .to eq([false, true, true, true, false])
      end

      it "offers reopen on a closed task" do
        done = create(:task, :done)
        read(done)

        expect(%w[start cancel complete stop reopen].map { action?(it, done) })
          .to eq([false, false, false, false, true])
      end

      it "offers no moves between lists" do
        read

        expect(page).to have_no_css("form[action*='/move/']")
      end

      it "carries where the task was opened into each action" do
        read(task, filter: "someday", origin: "today")
        form = page.find("form[action='/admin/tasks/#{task.id}/start']")

        expect(form.all("input[type='hidden']", visible: :all).to_h { [it["name"], it.value] })
          .to include("filter" => "someday", "origin" => "today")
      end

      {
        "complete" => ["/admin/tasks?filter=next", nil],
        "cancel" => ["/admin/tasks?filter=next", nil],
        "start" => ["/admin/tasks?filter=today", nil],
        "stop" => ["/admin/tasks?filter=next", :in_progress],
        "reopen" => ["/admin/tasks?filter=next", :done],
      }.each do |name, (back, trait)|
        it "sends #{name} back to the list it was opened from" do
          record = create(:task, *[trait].compact)
          send_to("/admin/tasks/#{record.id}/#{name}", filter: "next", origin: "tasks")

          expect(last_response).to be_redirect.and have_attributes(location: end_with(back))
        end
      end

      %w[complete cancel start].each do |name|
        it "sends #{name} back to Today when it was opened there" do
          send_to("/admin/tasks/#{task.id}/#{name}", filter: "today", origin: "today")

          expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin"))
        end
      end

      it "leads back to the list it was opened from" do
        read(task, filter: "next")

        expect(page).to have_link(label(:back_tasks), href: "/admin/tasks?filter=next")
      end

      it "leads back to Today when it was opened there" do
        read(task, origin: "today")

        expect(page).to have_link(label(:back_today), href: "/admin")
      end
    end

    describe "the links" do
      def hidden_fields(form) = form.all("input[type='hidden']", visible: :all).to_h { [it["name"].to_sym, it.value] }

      def link(kind: "blocks", other_id: other.id)
        fields = { filter: "next", origin: "tasks", link: { kind:, other_id: other_id.to_s } }
        send_to("/admin/tasks/#{task.id}/links", **fields)
      end

      def targets = page.all(".task-link-target").map { it.find(".task-key").text }

      def unlink_from_page
        create(:task_link, from_task_id: task.id, to_task_id: other.id)
        read(task, filter: "next")
        path = "/admin/tasks/#{task.id}/links/#{other.id}/delete"
        send_to(path, **hidden_fields(page.find(".task-link-row form[action='#{path}']")).except(:_csrf_token))
      end

      it "lists each link with its type" do
        create(:task_link, from_task_id: task.id, to_task_id: other.id)
        read

        expect(page.find(".task-link-row .task-link-label").text)
          .to eq(i18n.t("ui.components.tasks.links.labels.blocks"))
      end

      it "links each linked task to its own page, keeping where the task was opened" do
        create(:task_link, from_task_id: other.id, to_task_id: task.id)
        read(task, filter: "next", origin: "tasks")

        expect(page).to have_link("Write the migration", href: "/admin/tasks/#{other.id}?filter=next&origin=tasks")
      end

      it "finds tasks to link through a GET to the page itself", :aggregate_failures do
        other
        read(task, link_q: "migration")

        expect(page).to have_css("form.task-link-find[method='get'][action='/admin/tasks/#{task.id}']")
        expect(targets).to eq(["##{other.id}"])
      end

      it "keeps the query in the field" do
        read(task, link_q: "migration")

        expect(page.find("#task-#{task.id}-link-other-id").value).to eq("migration")
      end

      it "says when nothing matches" do
        read(task, link_q: "nothing like it")

        expect(page).to have_css(".task-link-editor", text: i18n.t("ui.components.tasks.link_editor.no_match"))
      end

      it "adds a link from the page and returns to where it was opened", :aggregate_failures do
        link

        expect(repo.by_id(task.id).links.map { [it.label, it.task.id] }).to eq([["blocks", other.id]])
        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=next"))
      end

      it "answers a failed link with 422" do
        link(other_id: task.id)

        expect(last_response.status).to eq(422)
      end

      it "shows the page again with the error beside the field", :aggregate_failures do
        link(other_id: task.id)

        expect(page).to have_css(".page-head h1", exact_text: "Ship the read page")
        expect(page.find("#task-#{task.id}-link-other-id-error").text)
          .to eq(i18n.t("ui.components.tasks.field_error.other_id.self"))
      end

      it "keeps the type that was picked after a failed link" do
        link(kind: "relates", other_id: task.id)

        expect(page.find("#task-#{task.id}-link-kind option[selected]").value).to eq("relates")
      end

      it "removes a link from the page and returns to where it was opened", :aggregate_failures do
        unlink_from_page

        expect(repo.by_id(task.id).links).to be_empty
        expect(last_response.location).to end_with("/admin/tasks?filter=next")
      end
    end
  end
end
