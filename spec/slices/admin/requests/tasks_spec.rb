# frozen_string_literal: true

RSpec.describe "Admin tasks", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:sprint_repo) { Tasks::Slice["repos.sprint_repo"] }

  def capture(title, filter: nil, **fields)
    post "/admin/tasks", { _csrf_token: admin_csrf_token, filter:, task: { title:, **fields } }.compact
  end

  def empty_text(filter) = i18n.t(["ui.views.tasks.index.empty", filter].join("."))

  def send_to(path, **params)
    post path, { _csrf_token: admin_csrf_token, **params }
  end

  def titles = page.all(".task-title, .li-title").map(&:text)

  def watch_carry_forward
    allow(repo).to receive(:carry_forward).and_call_original
    replace_component("repos.task_repo", repo)
  end

  def watch_finished
    allow(repo).to receive(:finished).and_call_original
    replace_component("repos.task_repo", repo)
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "answers with a server error when the day's sprint cannot be rolled" do
      create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today - 1).id)
      allow(sprint_repo).to receive(:by_id).and_return(nil)
      replace_component("repos.sprint_repo", sprint_repo)
      get "/admin/tasks"

      expect(last_response.status).to eq(500)
    end

    describe "the three lists" do
      before do
        sprint = create(:sprint, sprint_date: Blog::TimeZone.today)
        create(:task, :in_sprint, sprint_id: sprint.id, title: "Ship the screen")
        create(:task, title: "Email the accountant")
        create(:task, :someday, title: "Learn Elixir")
      end

      {
        "today" => "Ship the screen",
        "next" => "Email the accountant",
        "someday" => "Learn Elixir",
      }.each do |filter, listed|
        it "shows only the #{filter} tasks with the #{filter} filter" do
          get "/admin/tasks", filter: filter

          expect(titles).to eq([listed])
        end

        it "marks the #{filter} tab as the one you are on" do
          get "/admin/tasks", filter: filter

          expect(page).to have_css(".subtab.on[aria-current='page']", text: filter)
        end
      end

      it "titles the page Tasks" do
        get "/admin/tasks"

        expect(page).to have_title("Tasks | Admin | #{Blog::Owner.full_name}")
      end

      it "shows today without a filter" do
        get "/admin/tasks"

        expect(titles).to eq(["Ship the screen"])
      end

      it "shows today for a filter it doesn't know" do
        get "/admin/tasks", filter: "later"

        expect(titles).to eq(["Ship the screen"])
      end

      it "offers a tab for every list and the archive" do
        get "/admin/tasks"

        expect(page.all(".subtab span:first-of-type").map(&:text)).to eq(%w[today upcoming next someday external
                                                                            completed])
      end

      it "says nothing arrived in a sprint nothing was carried into" do
        get "/admin/tasks"

        expect(page).to have_css(".page-head-sub", text: "0 carried in")
      end

      it "counts every tab whichever is open" do
        create(:task, :done, title: "Filed already")
        get "/admin/tasks", filter: "someday"

        expect(page.all(".subtab-count").map(&:text)).to eq(%w[1 0 1 1 0 1])
      end

      it "keeps the count off the lists a finished task has left" do
        create(:task, :done, title: "Filed already")
        get "/admin/tasks", filter: "next"

        expect(titles).to eq(["Email the accountant"])
      end

      it "says what the sprint holds in the page sub" do
        get "/admin/tasks"

        expect(page).to have_css(".page-head-sub", text: "1 open in today · 0 carried in · 0 finished today")
      end

      it "counts what was finished today in the page sub" do
        create(:task, :done, title: "Filed already")
        get "/admin/tasks"

        expect(page).to have_css(".page-head-sub", text: "1 finished today")
      end

      it "leaves a task finished on an earlier day out of the page sub" do
        create(:task, :done, completed_at: Blog::TimeZone.day_start(Blog::TimeZone.today) - 60)
        get "/admin/tasks"

        expect(page).to have_css(".page-head-sub", text: "0 finished today")
      end

      it "counts a task finished on an earlier day on the completed tab" do
        create(:task, :done, completed_at: Blog::TimeZone.day_start(Blog::TimeZone.today) - 60)
        get "/admin/tasks"

        expect(page.all(".subtab-count").map(&:text).last).to eq("1")
      end

      %w[today upcoming next someday].each do |filter|
        it "reads no finished task on the #{filter} tab" do
          watch_finished
          get "/admin/tasks", filter: filter

          expect(repo).not_to have_received(:finished)
        end
      end

      it "reads the finished tasks on the completed tab" do
        watch_finished
        get "/admin/tasks", filter: "completed"

        expect(repo).to have_received(:finished)
      end

      it "dates the sprint in the page sub" do
        get "/admin/tasks"

        expect(page).to have_css(".page-head-sub", text: "Sprint #{Blog::TimeZone.today.strftime('%B %-d, %Y')}")
      end

      it "closes the screen with the note on how sprints roll" do
        get "/admin/tasks"

        expect(page).to have_css(".task-note", exact_text: i18n.t("ui.views.tasks.index.footnote"))
      end

      {
        "today" => ["Sprint · #{Blog::TimeZone.today.strftime('%b %-d')}", "the current sprint"],
        "next" => ["On deck", "queued up, not today"],
        "someday" => ["Backlog", "maybe, eventually, probably not"],
      }.each do |filter, (label, blurb)|
        it "labels the #{filter} card with its own label" do
          get "/admin/tasks", filter: filter

          expect(page).to have_css(".card-label", exact_text: label)
        end

        it "blurbs the #{filter} card" do
          get "/admin/tasks", filter: filter

          expect(page).to have_css(".card-blurb", text: blurb)
        end
      end

      it "counts what is open in the card it is showing" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_css(".card-note", exact_text: "1 open")
      end

      it "marks today as the live card" do
        get "/admin/tasks", filter: "today"

        expect(page).to have_css("section.card.card-live")
      end

      it "leaves the other lists unmarked" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_no_css("section.card.card-live")
      end

      it "offers no capture row" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_no_css(".task-capture")
      end
    end

    describe "the external list" do
      let!(:imported) do
        create(:task_source, task: create(:task, :external, title: "Fix the feed", tags: %w[site]), url: issue_url).task
      end

      def editor_lists = page.all("#task-#{imported.id}-form select[name='task[list]'] option").map(&:text)

      def held
        page.all("#task-#{imported.id}-form [name^='task[']", visible: :all)
            .to_h { [it["name"][/\Atask\[(\w+)\]\z/, 1], it.value] }
      end

      def import_linear
        task = create(:task, :external, title: "Ship the release")
        create(:task_source, task:, provider: "linear", remote_id: "lin-1", url: linear_url)
      end

      def issue_url = "https://github.com/aaronmallen/aaronmallen.me/issues/42"

      def linear_link = page.find(".task .task-meta a.task-source", text: "ABC-123")

      def linear_url = "https://linear.app/acme/issue/ABC-123/ship-the-release"

      before do
        create(:task, title: "Email the accountant")
        create(:task, :someday, title: "Learn Elixir")
      end

      it "lists only the imported open tasks on the external tab" do
        create(:task_source, task: create(:task, :external, :done, title: "Shipped already"))
        get "/admin/tasks", filter: "external"

        expect(titles).to eq(["Fix the feed"])
      end

      %w[next someday].each do |filter|
        it "keeps the imported tasks off #{filter}" do
          get "/admin/tasks", filter: filter

          expect(titles).not_to include("Fix the feed")
        end
      end

      it "marks the external tab as the one you are on" do
        get "/admin/tasks", filter: "external"

        expect(page).to have_css(".subtab.on[aria-current='page']", text: "external")
      end

      it "counts the imported tasks on their tab" do
        get "/admin/tasks", filter: "next"

        expect(page.find(".subtab", text: "external").find(".subtab-count").text).to eq("1")
      end

      it "labels and blurbs the card", :aggregate_failures do
        get "/admin/tasks", filter: "external"

        expect(page).to have_css(".card-label", exact_text: "From GitHub and Linear")
        expect(page).to have_css(".card-blurb", text: "open GitHub and Linear issues assigned to you")
      end

      it "says something useful when nothing is imported" do
        repo.delete(imported.id)
        get "/admin/tasks", filter: "external"

        expect(page).to have_css(".empty", exact_text: empty_text("external"))
      end

      it "links the row to its issue", :aggregate_failures do
        get "/admin/tasks", filter: "external"
        link = page.find(".task .task-meta a.task-source")

        expect(link["href"]).to eq(issue_url)
        expect(link.text).to eq("aaronmallen/aaronmallen.me#42")
      end

      it "marks a GitHub issue with GitHub's icon" do
        get "/admin/tasks", filter: "external"

        expect(page).to have_css(".task-source i.fa-brands.fa-github", visible: :all)
      end

      it "links a Linear row to its issue by its key" do
        import_linear
        get "/admin/tasks", filter: "external"

        expect(linear_link["href"]).to eq(linear_url)
      end

      it "marks a Linear issue with a Font Awesome Free solid icon", :aggregate_failures do
        import_linear
        get "/admin/tasks", filter: "external"

        expect(linear_link).to have_css("i.fa-solid.fa-circle-half-stroke[aria-hidden='true']", visible: :all)
        expect(linear_link).to have_no_css("i.fa-github", visible: :all)
      end

      it "leaves the GitHub row as it was beside a Linear one", :aggregate_failures do
        import_linear
        get "/admin/tasks", filter: "external"

        expect(page).to have_link("aaronmallen/aaronmallen.me#42", href: issue_url)
        expect(page).to have_link("ABC-123", href: linear_url)
      end

      it "leaves the issue link off a task written by hand" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_no_css(".task-source")
      end

      it "offers one move, into today" do
        get "/admin/tasks", filter: "external"

        expect(page.all(".task-acts form[action*='/move/']").map { it["action"] })
          .to eq(["/admin/tasks/#{imported.id}/move/today"])
      end

      it "offers external in the edit form, marked as the list it is in", :aggregate_failures do
        get "/admin/tasks/#{imported.id}/edit", filter: "external"

        expect(editor_lists).to eq(%w[today next someday external])
        expect(page.find("#task-#{imported.id}-form option[selected]").text).to eq("external")
      end

      it "keeps external out of the edit form of a task written by hand" do
        get "/admin/tasks/#{repo.in_list('next').first.id}/edit", filter: "next"

        expect(page.all(".task-form select[name='task[list]'] option").map(&:text))
          .to eq(%w[today next someday])
      end

      it "saves its tags and keeps it on external", :aggregate_failures do
        get "/admin/tasks/#{imported.id}/edit", filter: "external"
        send_to("/admin/tasks/#{imported.id}", filter: "external", task: { **held, "tags" => "site, bug" })

        expect(repo.by_id(imported.id).tags.map(&:name)).to contain_exactly("site", "bug")
        expect(repo.by_id(imported.id).list).to eq("external")
      end

      it "moves it to next through the edit form" do
        get "/admin/tasks/#{imported.id}/edit", filter: "external"
        send_to("/admin/tasks/#{imported.id}", filter: "external", task: { **held, "list" => "next" })

        expect(repo.by_id(imported.id).list).to eq("next")
      end

      it "names external as the place of a linked task" do
        other = create(:task, title: "Write the post")
        repo.link(other.id, imported.id, "relates")
        get "/admin/tasks/#{other.id}", filter: "next"

        expect(page).to have_css(".task-link-place", exact_text: "external")
      end
    end

    it "orders a list by position" do
      create(:task, title: "second", position: 2)
      create(:task, title: "first", position: 1)
      get "/admin/tasks", filter: "next"

      expect(titles).to eq(%w[first second])
    end

    %w[next someday].each do |filter|
      it "says something useful when #{filter} holds nothing" do
        get "/admin/tasks", filter: filter

        expect(page).to have_css(".empty", exact_text: empty_text(filter))
      end
    end

    describe "an empty sprint" do
      def planner(key, **) = i18n.t(["ui.components.tasks.planner", key].join("."), **)

      def pools = page.all(".task-planner .seg-option").map(&:text)

      it "asks what the day is for" do
        get "/admin/tasks", filter: "today"

        expect(page).to have_css(".task-planner .card-title", exact_text: planner("ask"))
      end

      it "heads the planner with the sprint date" do
        label = planner("label", date: Blog::TimeZone.today.strftime("%b %-d, %Y"))
        get "/admin/tasks", filter: "today"

        expect(page).to have_css(".task-planner .card-label", exact_text: label)
      end

      it "says the sprint is empty beside the question" do
        get "/admin/tasks", filter: "today"

        expect(page).to have_css(".task-planner .sprint-note", exact_text: planner("empty"))
      end

      it "leaves writing a task to the Create Task button" do
        get "/admin/tasks", filter: "today"

        expect(page).to have_no_css(".task-planner .task-capture")
      end

      it "lists what is waiting in next" do
        create(:task, title: "Email the accountant")
        create(:task, :someday, title: "Learn Elixir")
        get "/admin/tasks", filter: "today"

        expect(titles).to eq(["Email the accountant"])
      end

      it "counts every pool on the switch" do
        create(:task, title: "Email the accountant")
        create(:task, :someday, title: "Learn Elixir")
        create(:task_source, task: create(:task, :external, title: "Fix the feed"))
        get "/admin/tasks", filter: "today"

        expect(pools).to eq(["next · 1", "someday · 1", "external · 1"])
      end

      it "offers nothing already finished" do
        create(:task, :done, title: "Email the accountant")
        get "/admin/tasks", filter: "today"

        expect(pools).to eq(["next · 0", "someday · 0", "external · 0"])
      end

      it "lists someday when that pool is asked for" do
        create(:task, title: "Email the accountant")
        create(:task, :someday, title: "Learn Elixir")
        get "/admin/tasks", filter: "today", pool: "someday"

        expect(titles).to eq(["Learn Elixir"])
      end

      it "keeps the tasks screen when switching pools" do
        get "/admin/tasks", filter: "today"

        expect(page.all(".task-planner .seg-option").map { it["href"] })
          .to eq(%w[next someday external].map { "/admin/tasks?filter=today&pool=#{it}" })
      end

      it "marks the pool on show" do
        get "/admin/tasks", filter: "today", pool: "someday"

        expect(page).to have_css(".task-planner .seg-option.current", exact_text: "someday · 0")
      end

      it "shows the tags of a task it offers, and no type", :aggregate_failures do
        create(:task, title: "Email the accountant", tags: %w[admin])
        get "/admin/tasks", filter: "today"

        expect(page).to have_no_css(".task-planner .task-meta .pill")
        expect(page.all(".task-planner .task-meta .task-tag").map(&:text)).to eq(%w[#admin])
      end

      it "offers a pull straight into today" do
        task = create(:task)
        get "/admin/tasks", filter: "today"

        expect(page.all(".task-planner .li-side form").map { it["action"] })
          .to eq(["/admin/tasks/#{task.id}/move/today"])
      end

      it "says which pool is empty" do
        get "/admin/tasks", filter: "today"

        expect(page).to have_css(".task-planner .empty", exact_text: planner("empty_next"))
      end

      it "names the other pool when it is the empty one" do
        get "/admin/tasks", filter: "today", pool: "someday"

        expect(page).to have_css(".task-planner .empty", exact_text: planner("empty_someday"))
      end

      it "names external when it is the empty one" do
        get "/admin/tasks", filter: "today", pool: "external"

        expect(page).to have_css(".task-planner .empty", exact_text: planner("empty_external"))
      end

      it "drops the planner once the sprint holds a task", :aggregate_failures do
        create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today).id, title: "Ship it")
        get "/admin/tasks", filter: "today"

        expect(page).to have_no_css(".task-planner")
        expect(titles).to eq(["Ship it"])
      end

      it "keeps the planner off the other lists" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_no_css(".task-planner")
      end
    end

    describe "the external pool of an empty sprint" do
      let!(:task) do
        create(:task_source, task: create(:task, :external, title: "Fix the feed"), url: issue_url).task
      end

      def issue_url = "https://github.com/aaronmallen/aaronmallen.me/issues/42"

      it "lists the imported tasks" do
        create(:task, title: "Email the accountant")
        get "/admin/tasks", filter: "today", pool: "external"

        expect(titles).to eq(["Fix the feed"])
      end

      it "links each one to its issue" do
        get "/admin/tasks", filter: "today", pool: "external"

        expect(page).to have_link("aaronmallen/aaronmallen.me#42", href: issue_url)
      end

      it "links a Linear issue by its key" do
        url = "https://linear.app/acme/issue/ABC-123/ship-the-release"
        create(:task_source, task: create(:task, :external), provider: "linear", remote_id: "lin-1", url:)
        get "/admin/tasks", filter: "today", pool: "external"

        expect(page).to have_link("ABC-123", href: url)
      end

      it "pulls one into today's sprint", :aggregate_failures do
        send_to("/admin/tasks/#{task.id}/move/today", origin: "tasks")
        get "/admin/tasks", filter: "today"

        expect(repo.by_id(task.id)).to have_attributes(list: nil, sprint_id: sprint_repo.on(Blog::TimeZone.today).id)
        expect(page).to have_css(".task", text: "Fix the feed")
      end

      it "keeps the issue link on the task once it is in the sprint" do
        send_to("/admin/tasks/#{task.id}/move/today", origin: "tasks")
        get "/admin/tasks", filter: "today"

        expect(page.find(".task .task-meta a.task-source")["href"]).to eq(issue_url)
      end
    end

    describe "the Create Task button" do
      before { get "/admin/tasks", filter: "next" }

      def button = page.find(".page-head-actions a", text: "Create Task")

      it "leads to the page that holds the form" do
        expect(button["href"]).to eq("/admin/tasks/new")
      end

      it "opens the dialog in place when scripts run" do
        expect(button["data-dialog-open"]).to eq("task-create")
      end
    end

    describe "the new task page" do
      def fields = page.all("main form[action='/admin/tasks'] [name^='task[']").map { it["name"] }

      before { get "/admin/tasks/new" }

      it "answers 200" do
        expect(last_response.status).to eq(200)
      end

      it "asks for every field a task has but its type" do
        expect(fields).to eq(["task[title]", "task[note]", "task[list]", "task[sprint_on]", "task[tags]"])
      end

      it "puts a new task in next unless told otherwise" do
        expect(page).to have_select("task[list]", selected: "next")
      end
    end

    describe "the dialog" do
      def fields = page.all("dialog#task-create [name^='task[']", visible: :all).map { it["name"] }

      before { get "/admin" }

      it "sits in the layout of every screen, shut" do
        expect(page).to have_css("dialog#task-create[hidden]:not([open])", visible: :all)
      end

      it "holds the same fields as the new task page" do
        expect(fields).to eq(["task[title]", "task[note]", "task[list]", "task[sprint_on]", "task[tags]"])
      end
    end

    describe "capturing a task" do
      it "writes it down from one field" do
        capture("Email the accountant", filter: "next")

        expect(repo.in_list("next").map(&:title)).to eq(["Email the accountant"])
      end

      it "captures into the list that was open" do
        capture("Learn Elixir", filter: "someday")

        expect(repo.in_list("someday").map(&:title)).to eq(["Learn Elixir"])
      end

      it "captures into the current sprint from today" do
        capture("Ship the screen", filter: "today")

        expect(repo.in_sprint(sprint_repo.on(Blog::TimeZone.today).id).map(&:title)).to eq(["Ship the screen"])
      end

      it "carries the day's work forward once" do
        watch_carry_forward
        capture("Ship the screen", filter: "today")

        expect(repo).to have_received(:carry_forward).once
      end

      it "carries the day's work forward no more than once when it comes back with the form" do
        watch_carry_forward
        capture("", filter: "today")

        expect(repo).to have_received(:carry_forward).at_most(:once)
      end

      it "comes back to the list that was open" do
        capture("Learn Elixir", filter: "someday")

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=someday"))
      end

      it "says so" do
        capture("Email the accountant", filter: "next")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Task captured")
      end

      it "answers 422 for a task with no text" do
        capture("", filter: "next")

        expect(last_response.status).to eq(422)
      end

      it "says what is missing" do
        capture("", filter: "next")

        expect(page).to have_css(".field-error", text: i18n.t("ui.components.tasks.field_error.title.blank"))
      end

      it "writes nothing for a task with no text" do
        capture("", filter: "next")

        expect(repo.in_list("next")).to be_empty
      end

      it "keeps a #word in the title" do
        capture("Email the accountant #admin", filter: "next")

        expect(repo.in_list("next").first.title).to eq("Email the accountant #admin")
      end

      it "adds no tag for a #word in the title" do
        capture("Email the accountant #admin", filter: "next")

        expect(repo.in_list("next").first.tags).to be_empty
      end
    end

    describe "creating a task from the form" do
      def create_task(**fields)
        capture("Learn Elixir", list: "someday", note: "read the guide", tags: "elixir, learning", **fields)
      end

      def created = repo.in_list("someday").first

      it "writes down the title, note and list" do
        create_task

        expect(created).to have_attributes(title: "Learn Elixir", note: "read the guide", list: "someday")
      end

      it "gives it the tags in the field" do
        create_task

        expect(created.tags.map(&:name)).to contain_exactly("elixir", "learning")
      end

      it "takes the list from the form over the tab" do
        capture("Learn Elixir", filter: "next", list: "someday")

        expect(created.title).to eq("Learn Elixir")
      end

      it "comes back to the list it went in" do
        create_task

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=someday"))
      end

      it "puts it in the sprint for the date" do
        tomorrow = Blog::TimeZone.today + 1
        create_task(sprint_on: tomorrow.iso8601)

        expect(repo.in_sprint(sprint_repo.on(tomorrow).id).map(&:title)).to eq(["Learn Elixir"])
      end
    end

    describe "a failed save from the form" do
      before { capture("", list: "someday", note: "read the guide", tags: "not_a_tag") }

      it "answers 422" do
        expect(last_response.status).to eq(422)
      end

      it "shows the new task page" do
        expect(page).to have_css("main form[action='/admin/tasks'] [name='task[title]']")
      end

      it "says what went wrong", :aggregate_failures do
        expect(page).to have_css(".field-error", text: i18n.t("ui.components.tasks.field_error.title.blank"))
        expect(page).to have_css(".field-error", text: i18n.t("ui.components.tasks.field_error.tags.format"))
      end

      it "keeps what was typed", :aggregate_failures do
        expect(page).to have_field("task[note]", with: "read the guide")
        expect(page).to have_select("task[list]", selected: "someday")
        expect(page).to have_field("task[tags]", with: "not_a_tag")
      end

      it "writes nothing" do
        expect(repo.in_list("someday")).to be_empty
      end
    end

    describe "the shape of a row" do
      def keys = page.all(".task .task-key").map(&:text)

      {
        "today" => [:in_sprint],
        "next" => [],
        "someday" => [:someday],
        "completed" => [:done],
      }.each do |filter, traits|
        it "leads each #{filter} task with its key" do
          sprint = create(:sprint, sprint_date: Blog::TimeZone.today)
          tasks = Array.new(2) { create(:task, *traits, sprint_id: (sprint.id if traits.include?(:in_sprint))) }
          get "/admin/tasks", filter: filter

          expect(keys).to match_array(tasks.map { "##{it.id}" })
        end
      end

      it "leads each waiting task on the upcoming tab with its key" do
        task = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today + 1).id)
        get "/admin/tasks", filter: "upcoming"

        expect(keys).to eq(["##{task.id}"])
      end

      it "strikes through a task that is done" do
        create(:task, :done, title: "Filed already")
        get "/admin/tasks", filter: "completed"

        expect(page).to have_css(".task.done .task-title", text: "Filed already")
      end

      it "marks out the task in progress" do
        create(:task, :in_progress, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today).id)
        get "/admin/tasks"

        expect(page).to have_css(".task.doing")
      end

      it "says a task is in progress on its meta line" do
        create(:task, :in_progress, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today).id)
        get "/admin/tasks"

        expect(page).to have_css(".task-meta .pill.blue", text: i18n.t("ui.components.tasks.row.in_progress"))
      end

      it "leaves an open task unmarked", :aggregate_failures do
        create(:task)
        get "/admin/tasks", filter: "next"

        expect(page).to have_css(".task").and have_no_css(".task.doing")
        expect(page).to have_no_css(".task.done")
      end

      it "says the day and the time a task was finished" do
        at = Blog::TimeZone.local_time(2026, 9, 18, 11, 20)
        create(:task, :done, completed_at: at, title: "Filed already")
        get "/admin/tasks", filter: "completed"

        expect(page).to have_css(".task-finished", text: "done Sep 18 · 11:20")
      end

      it "offers a start on an open task", :aggregate_failures do
        create(:task)
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("form[action$='/start']")
        expect(page).to have_no_css("form[action$='/complete']")
      end

      it "offers a complete and a stop on the task in progress", :aggregate_failures do
        create(:task, :in_progress, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today).id)
        get "/admin/tasks"

        expect(page).to have_css("form[action$='/complete']")
        expect(page.all("form[action$='/stop']").size).to eq(1)
      end

      it "keeps the delete off the row" do
        create(:task)
        get "/admin/tasks", filter: "next"

        expect(page).to have_no_css(".task-acts form[action$='/delete']")
      end

      it "renders no edit form on a row" do
        create(:task)
        get "/admin/tasks", filter: "next"

        expect(page).to have_no_css(".task form[action$='/delete'], .task [name^='task[']")
      end

      it "links the title to the task's page, keeping the list it sits in" do
        task = create(:task, title: "Email the accountant")
        get "/admin/tasks", filter: "next"

        expect(page.find(".task a.task-title", text: "Email the accountant")["href"])
          .to eq("/admin/tasks/#{task.id}?filter=next&origin=tasks")
      end

      it "links a waiting task's title back to the upcoming tab" do
        task = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today + 1).id)
        get "/admin/tasks", filter: "upcoming"

        expect(page.find(".task a.task-title")["href"]).to eq("/admin/tasks/#{task.id}?filter=upcoming&origin=tasks")
      end

      it "links an archived task's title back to the archive" do
        task = create(:task, :done)
        get "/admin/tasks", filter: "completed"

        expect(page.find(".task a.task-title")["href"]).to eq("/admin/tasks/#{task.id}?filter=completed&origin=tasks")
      end
    end

    describe "moving a task" do
      it "moves it to someday" do
        task = create(:task)
        send_to("/admin/tasks/#{task.id}/move/someday")

        expect(repo.by_id(task.id).list).to eq("someday")
      end

      it "joins the current sprint on the way to today" do
        task = create(:task)
        send_to("/admin/tasks/#{task.id}/move/today")

        expect(repo.by_id(task.id)).to have_attributes(list: nil, sprint_id: sprint_repo.on(Blog::TimeZone.today).id)
      end

      it "follows the task to the list it went to" do
        task = create(:task)
        send_to("/admin/tasks/#{task.id}/move/someday")

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=someday"))
      end

      it "offers the list on either side of the one the task is in" do
        create(:task)
        get "/admin/tasks", filter: "next"

        expect(page.all(".task-acts form[action*='/move/']").map { it["action"] })
          .to eq(["/admin/tasks/#{repo.in_list('next').first.id}/move/today",
                  "/admin/tasks/#{repo.in_list('next').first.id}/move/someday"])
      end

      it "offers only the list to the right from the first one" do
        create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today).id)
        get "/admin/tasks", filter: "today"

        expect(page.all(".task-acts form[action*='/move/']").map { it["action"] })
          .to eq(["/admin/tasks/#{repo.in_sprint(sprint_repo.on(Blog::TimeZone.today).id).first.id}/move/next"])
      end

      it "offers only the list to the left from the last one" do
        create(:task, :someday)
        get "/admin/tasks", filter: "someday"

        expect(page.all(".task-acts form[action*='/move/']").map { it["action"] })
          .to eq(["/admin/tasks/#{repo.in_list('someday').first.id}/move/next"])
      end

      it "answers 404 for a task that isn't there" do
        send_to("/admin/tasks/0/move/someday")

        expect(last_response.status).to eq(404)
      end

      it "answers 404 for a list that isn't one" do
        task = create(:task)
        send_to("/admin/tasks/#{task.id}/move/later")

        expect(last_response.status).to eq(404)
      end
    end

    describe "starting a task" do
      it "sets it in progress" do
        task = create(:task)
        send_to("/admin/tasks/#{task.id}/start")

        expect(repo.by_id(task.id).status).to eq("in_progress")
      end

      it "puts it in today" do
        task = create(:task, :someday)
        send_to("/admin/tasks/#{task.id}/start")

        expect(repo.by_id(task.id)).to have_attributes(list: nil, sprint_id: sprint_repo.on(Blog::TimeZone.today).id)
      end

      it "lands on today" do
        task = create(:task)
        send_to("/admin/tasks/#{task.id}/start")

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=today"))
      end

      it "offers no start on a task already in progress in today" do
        create(:task, :in_progress, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today).id)
        get "/admin/tasks", filter: "today"

        expect(page).to have_no_css("form[action$='/start']")
      end

      it "offers start again on a task moved out of today while in progress" do
        task = create(:task, :in_progress, :in_sprint)
        send_to("/admin/tasks/#{task.id}/move/someday")
        get "/admin/tasks", filter: "someday"

        expect(page).to have_css("form[action$='/start']")
      end

      it "answers 404 for a task that isn't there" do
        send_to("/admin/tasks/0/start")

        expect(last_response.status).to eq(404)
      end
    end

    describe "stopping a task" do
      let(:task) do
        create(:task, :in_progress, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today).id)
      end

      it "takes it out of progress" do
        send_to("/admin/tasks/#{task.id}/stop", filter: "today")

        expect(repo.by_id(task.id).status).to eq("open")
      end

      it "keeps it in the sprint" do
        send_to("/admin/tasks/#{task.id}/stop", filter: "today")

        expect(repo.by_id(task.id).sprint_id).to eq(task.sprint_id)
      end

      it "says it stopped" do
        send_to("/admin/tasks/#{task.id}/stop", filter: "today")
        follow_redirect!

        expect(page).to have_css("[data-toast] .toast", exact_text: "Stopped · it waits in the sprint", visible: :all)
      end

      it "keeps the list that was open" do
        send_to("/admin/tasks/#{task.id}/stop", filter: "today")

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=today"))
      end

      it "answers 404 for a task that isn't there" do
        send_to("/admin/tasks/0/stop")

        expect(last_response.status).to eq(404)
      end
    end

    describe "finishing a task" do
      it "marks it done" do
        task = create(:task)
        send_to("/admin/tasks/#{task.id}/complete", filter: "next")

        expect(repo.by_id(task.id).status).to eq("done")
      end

      it "writes when it was finished" do
        task = create(:task)
        send_to("/admin/tasks/#{task.id}/complete", filter: "next")

        expect(repo.by_id(task.id).completed_at).not_to be_nil
      end

      it "opens it again" do
        task = create(:task, :done)
        send_to("/admin/tasks/#{task.id}/reopen", filter: "next")

        expect(repo.by_id(task.id).status).to eq("open")
      end

      it "says it reopened" do
        task = create(:task, :done)
        send_to("/admin/tasks/#{task.id}/reopen", filter: "completed")
        follow_redirect!

        expect(page).to have_css("[data-toast] .toast", exact_text: "Reopened", visible: :all)
      end

      it "clears the time when it is opened again" do
        task = create(:task, :done)
        send_to("/admin/tasks/#{task.id}/reopen", filter: "next")

        expect(repo.by_id(task.id).completed_at).to be_nil
      end

      it "offers reopen rather than done on a finished task" do
        create(:task, :done)
        get "/admin/tasks", filter: "completed"

        expect(page).to have_css("form[action$='/reopen']").and have_no_css("form[action$='/complete']")
      end

      it "takes it off the list it was in" do
        create(:task, :done, title: "Filed already")
        get "/admin/tasks", filter: "next"

        expect(titles).to be_empty
      end

      it "keeps the list that was open" do
        task = create(:task, :someday)
        send_to("/admin/tasks/#{task.id}/complete", filter: "someday")

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=someday"))
      end

      it "comes back to the archive from the archive" do
        task = create(:task, :done)
        send_to("/admin/tasks/#{task.id}/reopen", filter: "completed")

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=completed"))
      end

      it "answers 404 for finishing a task that isn't there" do
        send_to("/admin/tasks/0/complete")

        expect(last_response.status).to eq(404)
      end

      it "answers 404 for opening a task that isn't there" do
        send_to("/admin/tasks/0/reopen")

        expect(last_response.status).to eq(404)
      end
    end

    describe "canceling a task" do
      def cancel(task, filter: "next") = send_to("/admin/tasks/#{task.id}/cancel", filter:)

      it "offers a cancel on an open task" do
        create(:task)
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("form[action$='/cancel']")
      end

      it "offers a cancel on the task in progress" do
        create(:task, :in_progress, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today).id)
        get "/admin/tasks"

        expect(page).to have_css("form[action$='/cancel']")
      end

      it "marks it canceled" do
        task = create(:task)
        cancel(task)

        expect(repo.by_id(task.id).status).to eq("canceled")
      end

      it "writes when it was closed" do
        task = create(:task)
        cancel(task)

        expect(repo.by_id(task.id).completed_at).not_to be_nil
      end

      it "says it canceled" do
        task = create(:task)
        cancel(task)
        follow_redirect!

        expect(page).to have_css("[data-toast] .toast", exact_text: "Canceled", visible: :all)
      end

      it "keeps the list that was open" do
        task = create(:task, :someday)
        cancel(task, filter: "someday")

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=someday"))
      end

      it "takes it off the list it was in" do
        create(:task, :canceled, title: "Dropped")
        get "/admin/tasks", filter: "next"

        expect(titles).to be_empty
      end

      it "moves it to the completed tab" do
        create(:task, :canceled, title: "Dropped")
        get "/admin/tasks", filter: "completed"

        expect(titles).to eq(["Dropped"])
      end

      it "marks it canceled on the completed tab" do
        create(:task, :canceled, title: "Dropped")
        get "/admin/tasks", filter: "completed"

        expect(page).to have_css(".task.canceled .task-meta .pill", text: "canceled")
      end

      it "says the day and the time it was canceled" do
        at = Blog::TimeZone.local_time(2026, 9, 18, 11, 20)
        create(:task, :canceled, completed_at: at, title: "Dropped")
        get "/admin/tasks", filter: "completed"

        expect(page).to have_css(".task-finished", exact_text: "canceled Sep 18 · 11:20")
      end

      it "leaves the canceled mark off a task that is done" do
        create(:task, :done, title: "Filed already")
        get "/admin/tasks", filter: "completed"

        expect(page).to have_no_css(".task.canceled")
      end

      it "offers reopen and nothing else that moves it", :aggregate_failures do
        create(:task, :canceled)
        get "/admin/tasks", filter: "completed"

        expect(page).to have_css("form[action$='/reopen']")
        expect(page).to have_no_css("form[action$='/cancel'], form[action$='/complete'], form[action*='/move/']")
      end

      it "opens it again" do
        task = create(:task, :canceled)
        send_to("/admin/tasks/#{task.id}/reopen", filter: "completed")

        expect(repo.by_id(task.id)).to have_attributes(status: "open", completed_at: nil)
      end

      it "puts it back on its list once opened again" do
        task = create(:task, :canceled, title: "Dropped")
        send_to("/admin/tasks/#{task.id}/reopen", filter: "completed")
        get "/admin/tasks", filter: "next"

        expect(titles).to eq(["Dropped"])
      end

      it "leaves a task that is done as it was" do
        task = create(:task, :done)
        cancel(task)

        expect(repo.by_id(task.id).status).to eq("done")
      end

      it "says a task that is done is closed already" do
        task = create(:task, :done)
        cancel(task, filter: "completed")
        follow_redirect!

        expect(page).to have_css("[data-toast] .toast", exact_text: "That task is closed already", visible: :all)
      end

      it "answers 404 for a task that isn't there" do
        send_to("/admin/tasks/0/cancel")

        expect(last_response.status).to eq(404)
      end

      it "leaves a canceled task out of a planned sprint's card" do
        sprint = create(:sprint, sprint_date: Blog::TimeZone.today + 1)
        create(:task, :in_sprint, sprint:, title: "Still on")
        create(:task, :canceled, :in_sprint, sprint:, title: "Dropped")
        get "/admin/tasks", filter: "upcoming"

        expect(titles).to eq(["Still on"])
      end

      it "leaves a canceled task out of a planned sprint's count" do
        sprint = create(:sprint, sprint_date: Blog::TimeZone.today + 1)
        create(:task, :canceled, :in_sprint, sprint:)
        get "/admin/tasks", filter: "upcoming"

        expect(page).to have_css(".sprint-note", exact_text: "0 planned")
      end

      it "names a canceled task's place in the link editor" do
        task = create(:task, title: "Still on")
        create(:task, :canceled, title: "Dropped")
        get "/admin/tasks/#{task.id}", filter: "next", link_q: "Dropped"

        expect(page).to have_css(".task-link-target .task-link-place", exact_text: "canceled")
      end
    end

    describe "the edit page" do
      let(:task) { create(:task, title: "Email accountant", note: "Ring before ten", tags: %w[ruby admin]) }

      def fields = page.all("#task-#{task.id}-form [name^='task[']").map { it["name"] }

      def open_edit(**params) = get("/admin/tasks/#{task.id}/edit", params)

      it "answers 200" do
        open_edit

        expect(last_response.status).to eq(200)
      end

      it "answers 404 for a task that isn't there" do
        get "/admin/tasks/0/edit"

        expect(last_response.status).to eq(404)
      end

      it "heads the page with the title" do
        open_edit

        expect(page).to have_css("h1.page-head-title", exact_text: "Email accountant")
      end

      it "posts to the task's update" do
        open_edit

        expect(page).to have_css("form#task-#{task.id}-form[method='post'][action='/admin/tasks/#{task.id}']")
      end

      it "holds the same fields as the new task page" do
        open_edit

        expect(fields).to eq(["task[title]", "task[note]", "task[list]", "task[sprint_on]", "task[tags]"])
      end

      it "fills the fields with the task", :aggregate_failures do
        open_edit

        expect(page).to have_field("task[title]", with: "Email accountant")
        expect(page.find("textarea[name='task[note]']").text).to eq("Ring before ten")
        expect(page).to have_select("task[list]", selected: "next")
        expect(page).to have_field("task[tags]", with: "admin, ruby")
      end

      it "leaves the note field empty for a task without one" do
        task = create(:task)
        get "/admin/tasks/#{task.id}/edit"

        expect(page.find("textarea[name='task[note]']").text).to be_empty
      end

      it "reads today back for a task in the sprint" do
        task = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today).id)
        get "/admin/tasks/#{task.id}/edit"

        expect(page).to have_select("task[list]", selected: "today")
      end

      it "carries where the task was opened into the form", :aggregate_failures do
        open_edit(filter: "upcoming", origin: "today")
        form = page.find("#task-#{task.id}-form")

        expect(form.find("input[name='filter']", visible: :all).value).to eq("upcoming")
        expect(form.find("input[name='origin']", visible: :all).value).to eq("today")
      end

      it "leads Cancel and the back button to the task's page", :aggregate_failures do
        open_edit(filter: "next", origin: "tasks")
        read = "/admin/tasks/#{task.id}?filter=next&origin=tasks"

        expect(page.find(".task-form-foot a", text: i18n.t("ui.views.tasks.edit.cancel"))["href"]).to eq(read)
        expect(page.find(".page-head-actions a", text: i18n.t("ui.views.tasks.edit.back"))["href"]).to eq(read)
      end

      it "offers a delete that asks first, naming the task", :aggregate_failures do
        open_edit
        form = page.find("form#task-#{task.id}-delete[action='/admin/tasks/#{task.id}/delete']")

        expect(form["data-confirm"]).to include("Email accountant")
        expect(page).to have_css("button[form='task-#{task.id}-delete']", text: i18n.t("ui.views.tasks.edit.delete"))
      end

      it "wraps the form in a part a dialog can lift" do
        open_edit

        expect(page).to have_css("main [data-task-edit='#{task.id}'] form#task-#{task.id}-form")
      end

      it "is linked from the task's page as Edit" do
        get "/admin/tasks/#{task.id}", filter: "next", origin: "tasks"

        expect(page.find("a", exact_text: i18n.t("ui.views.tasks.show.edit"))["href"])
          .to eq("/admin/tasks/#{task.id}/edit?filter=next&origin=tasks")
      end
    end

    describe "editing a task" do
      let(:task) { create(:task, title: "Email accountant") }

      def edit(**fields)
        written = { title: "Email the accountant", list: "", note: "", tags: "", **fields }

        send_to("/admin/tasks/#{task.id}", filter: "next", task: written)
      end

      it "rewrites the text" do
        edit

        expect(repo.by_id(task.id).title).to eq("Email the accountant")
      end

      it "writes a note on it" do
        edit(note: "Ring before ten")

        expect(repo.by_id(task.id).note).to eq("Ring before ten")
      end

      it "tags it" do
        edit(tags: "ruby, admin")

        expect(repo.by_id(task.id).tags.map(&:name)).to eq(%w[admin ruby])
      end

      it "shows the tags on the row in their own colour" do
        edit(tags: "ruby")
        get "/admin/tasks", filter: "next"
        hue = Blog::UI::Components::Pill.for_tag_color(repo.by_id(task.id).tags.first.color)

        expect(page).to have_css(".task-meta .task-tag.#{hue}", text: "#ruby")
      end

      it "draws no type on the row" do
        task
        get "/admin/tasks", filter: "next"

        expect(page).to have_no_css(".task-meta .pill")
      end

      it "draws the key in no colour" do
        edit(tags: "ruby")
        get "/admin/tasks", filter: "next"

        expect(page.find(".task .task-key")["class"]).to eq("task-key")
      end

      it "says so" do
        edit
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Task saved")
      end

      it "comes back to the list it was opened from" do
        edit

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/tasks?filter=next"))
      end

      it "comes back to Today when it was opened there" do
        send_to("/admin/tasks/#{task.id}", filter: "today", origin: "today", task: { title: "Email the accountant" })

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin"))
      end

      it "answers 404 for a task that isn't there" do
        send_to("/admin/tasks/0", filter: "next", task: { title: "Anything" })

        expect(last_response.status).to eq(404)
      end

      it "moves the task to the list it was given" do
        edit(list: "someday")

        expect(repo.by_id(task.id).list).to eq("someday")
      end

      it "joins the sprint on the way to today", :aggregate_failures do
        edit(list: "today")

        expect(repo.by_id(task.id).sprint_id).to eq(sprint_repo.on(Blog::TimeZone.today).id)
        expect(repo.by_id(task.id).list).to be_nil
      end

      it "leaves the task where it is when the list did not change" do
        edit(list: "next")

        expect(repo.by_id(task.id).list).to eq("next")
      end

      it "answers 422 for a list that is not one" do
        edit(list: "later")

        expect(last_response.status).to eq(422)
      end
    end

    describe "a failed edit" do
      let(:task) { create(:task, title: "Email accountant") }

      before do
        send_to(
          "/admin/tasks/#{task.id}",
          filter: "someday", origin: "tasks",
          task: { title: " ", note: "Ring before ten", list: "someday", tags: "not_a_tag", sprint_on: "" },
        )
      end

      it "answers 422" do
        expect(last_response.status).to eq(422)
      end

      it "shows the edit page for the task it refused" do
        expect(page).to have_css("main [data-task-edit='#{task.id}'] form[action='/admin/tasks/#{task.id}']")
      end

      it "says what went wrong beside the fields", :aggregate_failures do
        expect(page.find("#task-#{task.id}-title-error"))
          .to have_text(i18n.t("ui.components.tasks.field_error.title.blank"))
        expect(page.find("#task-#{task.id}-tags-error"))
          .to have_text(i18n.t("ui.components.tasks.field_error.tags.format"))
      end

      it "keeps what was typed", :aggregate_failures do
        expect(page).to have_field("task[title]", with: " ")
        expect(page.find("textarea[name='task[note]']").text).to eq("Ring before ten")
        expect(page).to have_select("task[list]", selected: "someday")
        expect(page).to have_field("task[tags]", with: "not_a_tag")
      end

      it "keeps where the task was opened", :aggregate_failures do
        form = page.find("#task-#{task.id}-form")

        expect(form.find("input[name='filter']", visible: :all).value).to eq("someday")
        expect(form.find("input[name='origin']", visible: :all).value).to eq("tasks")
      end

      it "writes nothing" do
        expect(repo.by_id(task.id)).to have_attributes(title: "Email accountant", note: task.note, list: "next")
      end
    end

    describe "saving a task from its edit page" do
      let(:sprint) { create(:sprint, sprint_date: today) }

      def date_field(task) = page.find("#task-#{task.id}-form [name='task[sprint_on]']", visible: :all)

      def held(task)
        page.all("#task-#{task.id}-form [name^='task[']", visible: :all)
            .to_h { [it[:name][/\[(\w+)\]/, 1].to_sym, it.value.to_s] }
      end

      def save(task, filter:, **changes)
        get "/admin/tasks/#{task.id}/edit", filter: filter
        send_to("/admin/tasks/#{task.id}", filter:, task: { **held(task), **changes })
      end

      def today = Blog::TimeZone.today

      it "shows the sprint's date for a task in today's sprint" do
        task = create(:task, :in_sprint, sprint_id: sprint.id)
        get "/admin/tasks/#{task.id}/edit"

        expect(date_field(task).value).to eq(today.iso8601)
      end

      it "shows the date of the sprint a finished task ran in", :aggregate_failures do
        task = create(:task, :done, :in_sprint, sprint: create(:sprint, sprint_date: today - 1))
        get "/admin/tasks/#{task.id}/edit", filter: "completed"

        expect(date_field(task).value).to eq((today - 1).iso8601)
        expect(date_field(task)[:min]).to eq((today - 1).iso8601)
      end

      it "leaves a sprint task saved from the today tab with nothing changed where it is" do
        task = create(:task, :in_sprint, :carried, sprint_id: sprint.id)
        save(task, filter: "today")

        expect(repo.by_id(task.id)).to have_attributes(sprint_id: sprint.id, carried_count: 2)
      end

      it "leaves a finished task saved from the completed tab on the sprint it ran in" do
        ran = create(:sprint, sprint_date: today - 1)
        task = create(:task, :done, :in_sprint, sprint_id: ran.id)
        save(task, filter: "completed")

        expect(repo.by_id(task.id).sprint_id).to eq(ran.id)
      end

      it "moves a sprint task to next when next is picked, though the sprint's date comes with it" do
        task = create(:task, :in_sprint, :carried, sprint_id: sprint.id)
        save(task, filter: "today", list: "next")

        expect(repo.by_id(task.id)).to have_attributes(list: "next", sprint_id: nil, carried_count: 0)
      end

      it "moves a waiting task to someday when someday is picked on the upcoming tab" do
        task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today + 1))
        save(task, filter: "upcoming", list: "someday")

        expect(repo.by_id(task.id)).to have_attributes(list: "someday", sprint_id: nil)
      end

      it "joins today's sprint when today is picked for a next task, though its date is blank" do
        task = create(:task)
        save(task, filter: "next", list: "today", sprint_on: "")

        expect(repo.by_id(task.id)).to have_attributes(list: nil, sprint_id: sprint_repo.on(Blog::TimeZone.today).id)
      end

      it "sends a sprint task to next when its date is cleared" do
        task = create(:task, :in_sprint, sprint_id: sprint.id)
        save(task, filter: "today", sprint_on: "")

        expect(repo.by_id(task.id)).to have_attributes(list: "next", sprint_id: nil)
      end

      it "sends a sprint task with a source to external when its date is cleared" do
        task = create(:task_source, task: create(:task, :in_sprint, sprint_id: sprint.id)).task
        save(task, filter: "today", sprint_on: "")

        expect(repo.by_id(task.id)).to have_attributes(list: "external", sprint_id: nil)
      end

      it "moves a waiting task to the day it was given when only its date changed" do
        task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today + 1))
        save(task, filter: "upcoming", sprint_on: (today + 2).iso8601)

        expect(repo.by_id(task.id).sprint_id).to eq(sprint_repo.on(today + 2).id)
      end
    end

    describe "a task that was carried" do
      let(:yesterday) { create(:sprint, sprint_date: Blog::TimeZone.today - 1) }

      it "says so on the row" do
        create(:task, :in_sprint, sprint_id: yesterday.id, title: "Ship the screen")
        get "/admin/tasks"

        expect(page).to have_css(".task-meta .pill.sand", text: "carried ×1")
      end

      it "says nothing on a task that was never carried" do
        create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today).id)
        get "/admin/tasks"

        expect(page).to have_no_css(".task-meta .pill", text: "carried")
      end

      it "says nothing once it is finished" do
        create(:task, :carried, :done, :in_sprint, sprint_id: create(:sprint, sprint_date: Blog::TimeZone.today).id)
        get "/admin/tasks"

        expect(page).to have_no_css(".task-meta .pill", text: "carried")
      end

      it "counts what arrived in the sprint" do
        2.times { create(:task, :in_sprint, sprint_id: yesterday.id) }
        get "/admin/tasks"

        expect(page).to have_css(".page-head-sub", text: "2 carried in")
      end
    end

    describe "deleting a task" do
      it "takes it away" do
        task = create(:task)
        send_to("/admin/tasks/#{task.id}/delete", filter: "next")

        expect(repo.by_id(task.id)).to be_nil
      end

      it "asks first" do
        task = create(:task, title: "Email the accountant")
        get "/admin/tasks/#{task.id}/edit", filter: "next"

        expect(page).to have_css("form[action$='/delete'][data-confirm]")
      end

      it "names the task it is about to take away" do
        task = create(:task, title: "Email the accountant")
        get "/admin/tasks/#{task.id}/edit", filter: "next"

        expect(page.find("form[action$='/delete']")["data-confirm"]).to include("Email the accountant")
      end

      it "answers 404 for a task that isn't there" do
        send_to("/admin/tasks/0/delete")

        expect(last_response.status).to eq(404)
      end
    end

    describe "reordering a task" do
      before do
        create(:task, title: "first", position: 1)
        create(:task, title: "second", position: 2)
      end

      it "moves a task up past the one above it" do
        send_to("/admin/tasks/#{repo.in_list('next').last.id}/reorder/up", filter: "next")

        expect(repo.in_list("next").map(&:title)).to eq(%w[second first])
      end

      it "moves a task down past the one below it" do
        send_to("/admin/tasks/#{repo.in_list('next').first.id}/reorder/down", filter: "next")

        expect(repo.in_list("next").map(&:title)).to eq(%w[second first])
      end

      it "holds the caret that has nowhere to go", :aggregate_failures do
        get "/admin/tasks", filter: "next"
        carets = page.all(".task-order button")

        expect(carets.first).to be_disabled
        expect(carets.last).to be_disabled
      end

      it "redirects back to the list at the top rather than failing" do
        send_to("/admin/tasks/#{repo.in_list('next').first.id}/reorder/up", filter: "next")

        expect(last_response).to be_redirect
      end

      it "answers 404 for a direction that isn't one" do
        send_to("/admin/tasks/#{repo.in_list('next').first.id}/reorder/sideways")

        expect(last_response.status).to eq(404)
      end

      it "answers 404 for a task that isn't there" do
        send_to("/admin/tasks/0/reorder/up")

        expect(last_response.status).to eq(404)
      end
    end

    describe "a title holding HTML" do
      let(:markup) { "<script>alert('x')</script>" }

      before do
        create(:task, title: markup)
        get "/admin/tasks", filter: "next"
      end

      it "reads it back as the text it is" do
        expect(page).to have_css(".task-title", text: markup)
      end

      it "escapes it rather than serving it as markup" do
        expect(last_response.body).to include("&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;")
      end

      it "keeps a quoted title inside the attribute that carries it" do
        get "/admin/tasks/#{create(:task, title: 'Ask "why"').id}/edit", filter: "next"

        expect(page.all("form[action$='/delete']").map { it["data-confirm"] })
          .to include(include('Ask "why"'))
      end
    end

    describe "a forged CSRF token" do
      it "refuses the capture" do
        post "/admin/tasks", _csrf_token: "forged", task: { title: "Email the accountant" }

        expect(last_response.status).to eq(403)
      end

      it "writes nothing" do
        post "/admin/tasks", _csrf_token: "forged", task: { title: "Email the accountant" }

        expect(repo.in_list("next")).to be_empty
      end

      it "refuses a move" do
        task = create(:task)
        post "/admin/tasks/#{task.id}/move/someday", _csrf_token: "forged"

        expect(repo.by_id(task.id).list).to eq("next")
      end
    end

    it "carries a token in every form on the page" do
      create(:task)
      get "/admin/tasks", filter: "next"

      expect(page.all("main form[method='post']", visible: :all)
        .map { it.first("input[name='_csrf_token']", visible: :all) })
        .to all(be_truthy)
    end

    it "adds no navigation entry" do
      get "/admin/tasks"

      expect(page).to have_no_css(".tab-strip a[href='/admin/tasks']")
    end

    describe "searching" do
      def filters(key) = i18n.t(["ui.components.tasks.filters", key].join("."))

      def index(key) = i18n.t(["ui.views.tasks.index", key].join("."))

      def search(query, **) = get("/admin/tasks", { q: query, filter: "next", ** })

      before do
        create(:task, title: "Email the accountant", tags: %w[admin])
        create(:task, title: "Ship the search", tags: %w[ruby])
        create(:task, :someday, title: "Learn Elixir", tags: %w[elixir])
      end

      it "narrows the open list by a word in the title" do
        search("accountant")

        expect(titles).to eq(["Email the accountant"])
      end

      it "leaves the other lists alone" do
        search("elixir")

        expect(titles).to be_empty
      end

      it "narrows the list it is given" do
        search("elixir", filter: "someday")

        expect(titles).to eq(["Learn Elixir"])
      end

      it "narrows by tag" do
        search("tag:ruby")

        expect(titles).to eq(["Ship the search"])
      end

      it "reads type: as plain text" do
        search("type:chore")

        expect(titles).to be_empty
      end

      it "searches the words beside a term as text" do
        search("tag:ruby ship")

        expect(titles).to eq(["Ship the search"])
      end

      it "says so when nothing in the list matches" do
        search("nothing here")

        expect(page).to have_css(".empty", exact_text: index("empty.no_match"))
      end

      it "keeps the query in the field" do
        search("tag:ruby")

        expect(page).to have_field(filters("search"), with: "tag:ruby")
      end

      it "carries no label over the field" do
        search("")

        expect(page).to have_css("label.sr-only[for='tasks-q']")
      end

      it "spells no query syntax out under the field" do
        search("")

        expect(page).to have_no_css("form[role='search'] .hint")
      end

      it "asks for the search the design asks for" do
        search("")

        expect(page.find_by_id("tasks-q")["placeholder"]).to eq("search · tag:site…")
      end

      it "shows the whole list again once the query is dropped" do
        search("")

        expect(titles).to eq(["Email the accountant", "Ship the search"])
      end

      it "keeps the query on a tab it is carried to" do
        search("ship")

        expect(page.all(".subtab").map { it["href"] }).to all(include("q=ship"))
      end
    end

    describe "the filters beside the search" do
      before do
        create(:task, title: "Email the accountant")
        create(:task, title: "Ship the search")
      end

      it "offers no type select" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_no_select("type", visible: :all)
      end

      it "offers no link to a types screen" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_no_link(href: "/admin/tasks/types")
      end

      it "ignores a type left in the address" do
        get "/admin/tasks", filter: "next", type: "1"

        expect(titles).to eq(["Email the accountant", "Ship the search"])
      end

      it "answers 404 where the types screen was" do
        get "/admin/tasks/types"

        expect(last_response.status).to eq(404)
      end
    end

    describe "the archive" do
      def day_heads = page.all(".task-day-date").map(&:text)

      def finished(title, days_ago, hour, **)
        day = Blog::TimeZone.today
        at = Blog::TimeZone.local_time(day.year, day.month, day.day, hour) - (days_ago * 86_400)

        create(:task, :done, title:, completed_at: at, **)
      end

      def index(key, **) = i18n.t(["ui.views.tasks.index", key].join("."), **)

      before do
        finished("Seed the queue", 2, 9)
        finished("Move the toggle", 1, 11)
        finished("Index the activities", 1, 15)
        finished("Ship the screen", 0, 8)
      end

      it "groups the finished work by the day it was finished" do
        get "/admin/tasks", filter: "completed"

        expect(day_heads.size).to eq(3)
      end

      it "puts the newest day first" do
        get "/admin/tasks", filter: "completed"

        expect(day_heads.first).to eq(Blog::TimeZone.today.strftime("%B %-d, %Y"))
      end

      it "puts the newest task first inside a day" do
        get "/admin/tasks", filter: "completed"

        expect(titles).to eq(["Ship the screen", "Index the activities", "Move the toggle", "Seed the queue"])
      end

      it "says how long ago each day was and what it holds" do
        get "/admin/tasks", filter: "completed"

        expect(page.all(".task-day-count").map(&:text))
          .to eq(["#{i18n.t('ui.components.tasks.completed_day.today')} · 1",
                  "#{i18n.t('ui.components.tasks.completed_day.yesterday')} · 2",
                  "#{i18n.t('ui.components.tasks.completed_day.days_ago', count: 2)} · 1"])
      end

      it "counts every finished task on the tab" do
        get "/admin/tasks", filter: "completed"

        expect(page.all(".subtab-count").last.text).to eq("4")
      end

      it "files the archive under its own label" do
        get "/admin/tasks", filter: "completed"

        expect(page).to have_css(".card-label", exact_text: index("archive"))
      end

      it "says how many it is showing" do
        get "/admin/tasks", filter: "completed"

        expect(page).to have_css(".card-note", exact_text: index("shown", count: 4))
      end

      it "offers no move out of the archive on a finished task" do
        get "/admin/tasks", filter: "completed"

        expect(page).to have_no_css("form[action*='/move/']")
      end

      it "offers no reordering in the archive" do
        get "/admin/tasks", filter: "completed"

        expect(page).to have_no_css(".task-order")
      end

      it "offers no capture field in the archive" do
        get "/admin/tasks", filter: "completed"

        expect(page).to have_no_css(".task-capture")
      end

      it "narrows the archive by a search" do
        get "/admin/tasks", filter: "completed", q: "toggle"

        expect(titles).to eq(["Move the toggle"])
      end

      it "blames the filters when they empty it" do
        get "/admin/tasks", filter: "completed", q: "nothing here"

        expect(page).to have_css(".empty", exact_text: index("empty.completed_no_match"))
      end
    end

    describe "an empty archive" do
      it "says nothing is finished yet" do
        get "/admin/tasks", filter: "completed"

        expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.tasks.index.empty.completed"))
      end
    end

    describe "planning a sprint ahead" do
      def drop(sprint) = send_to("/admin/tasks/sprints/#{sprint.id}/delete")

      def edit(task, **fields)
        send_to("/admin/tasks/#{task.id}", filter: "next", task: { title: task.title, **fields })
      end

      def plan(on) = send_to("/admin/tasks/sprints", sprint_on: on.to_s)

      def today = Blog::TimeZone.today

      def tomorrow = today + 1

      def upcoming = get("/admin/tasks", filter: "upcoming")

      it "opens a sprint for a day after today" do
        plan(tomorrow.iso8601)

        expect(sprint_repo.on(tomorrow)).not_to be_nil
      end

      it "says which day it planned" do
        plan(tomorrow.iso8601)
        follow_redirect!

        expect(page).to have_css("[data-toast] .toast", text: tomorrow.strftime("%b %-d, %Y"), visible: :all)
      end

      it "comes back to the upcoming tab" do
        plan(tomorrow.iso8601)

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=upcoming")
      end

      it "says so rather than making a second sprint for the same day" do
        create(:sprint, sprint_date: tomorrow)
        plan(tomorrow.iso8601)
        follow_redirect!

        expect(page).to have_css("[data-toast] .toast", text: "already exists", visible: :all)
      end

      it "makes no sprint for a day that is over" do
        plan((today - 1).iso8601)

        expect(sprint_repo.on(today - 1)).to be_nil
      end

      it "makes no sprint for today" do
        plan(today.iso8601)

        expect(sprint_repo.on(today)).to be_nil
      end

      {
        "today" => -> { today },
        "a day that is over" => -> { today - 1 },
      }.each do |named, day|
        it "asks for a day after today when asked to plan #{named}" do
          plan(instance_exec(&day).iso8601)
          follow_redirect!

          expect(page)
            .to have_css("[data-toast] .toast", exact_text: "Plan a sprint for a day after today", visible: :all)
        end
      end

      it "lists each planned sprint with the day it falls on" do
        create(:sprint, sprint_date: tomorrow)
        upcoming

        expect(page).to have_css(".card-title", text: tomorrow.strftime("%A, %B %-d"))
      end

      it "counts the tasks waiting on a planned sprint in the head" do
        create(:task, :in_sprint, sprint: create(:sprint, sprint_date: tomorrow))
        upcoming

        expect(page).to have_css(".page-head-sub", text: "1 upcoming")
      end

      it "says nothing is planned when nothing is" do
        upcoming

        expect(page).to have_css(".empty", text: "No future sprints")
      end

      it "drops a sprint" do
        sprint = create(:sprint, sprint_date: tomorrow)
        drop(sprint)

        expect(sprint_repo.on(tomorrow)).to be_nil
      end

      it "sends the dropped sprint's tasks back to next" do
        sprint = create(:sprint, sprint_date: tomorrow)
        task = create(:task, :in_sprint, sprint_id: sprint.id)
        drop(sprint)

        expect(repo.by_id(task.id)).to have_attributes(list: "next", sprint_id: nil)
      end

      it "sends the dropped sprint's tasks with a source back to external" do
        sprint = create(:sprint, sprint_date: tomorrow)
        task = create(:task_source, task: create(:task, :in_sprint, sprint_id: sprint.id)).task
        drop(sprint)

        expect(repo.by_id(task.id)).to have_attributes(list: "external", sprint_id: nil)
      end

      it "sends a task with no source back to next beside one with a source" do
        sprint = create(:sprint, sprint_date: tomorrow)
        create(:task_source, task: create(:task, :in_sprint, sprint_id: sprint.id))
        task = create(:task, :in_sprint, sprint_id: sprint.id)
        drop(sprint)

        expect(repo.by_id(task.id).list).to eq("next")
      end

      it "says where the dropped sprint's tasks went" do
        drop(create(:sprint, sprint_date: tomorrow))
        follow_redirect!

        expect(page).to have_css("[data-toast] .toast", text: "went back to their lists", visible: :all)
      end

      it "keeps the sprint the day is running" do
        sprint = create(:sprint, sprint_date: today)
        drop(sprint)

        expect(sprint_repo.on(today)).not_to be_nil
      end

      it "answers 404 for a sprint nobody opened" do
        send_to("/admin/tasks/sprints/0/delete")

        expect(last_response.status).to eq(404)
      end

      it "captures a task straight into a planned sprint" do
        sprint = create(:sprint, sprint_date: tomorrow)
        capture("Tomorrow's work", filter: "next", sprint_on: tomorrow.iso8601)

        expect(repo.in_sprint(sprint.id).map(&:title)).to eq(["Tomorrow's work"])
      end

      it "captures a task into today's sprint for today's date" do
        capture("Today's work", filter: "next", sprint_on: today.iso8601)

        expect(repo.in_sprint(sprint_repo.on(today).id).map(&:title)).to eq(["Today's work"])
      end

      it "lands a task captured onto a sprint on upcoming" do
        capture("Tomorrow's work", filter: "next", sprint_on: tomorrow.iso8601)

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=upcoming")
      end

      it "says why it refused a captured task's date it cannot read" do
        capture("Someday's work", filter: "next", sprint_on: "next week")
        follow_redirect!

        expect(page).to have_css("[data-toast] .toast", text: "A sprint opens on today", visible: :all)
      end

      {
        "the day it was scheduled for" => [-> { tomorrow.iso8601 }, "Scheduled for the"],
        "that it joined today's sprint" => [-> { today.iso8601 }, "Pulled into today's sprint"],
        "that it went back to next" => [-> { "" }, "Unscheduled · back in next"],
        "why it refused a day that is over" => [-> { (today - 1).iso8601 }, "A sprint opens on today"],
      }.each do |named, (asked, toast)|
        it "says #{named} when a task is scheduled" do
          task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today + 2))
          send_to("/admin/tasks/#{task.id}/schedule", sprint_on: instance_exec(&asked))
          follow_redirect!

          expect(page).to have_css("[data-toast] .toast", text: toast, visible: :all)
        end
      end

      it "says an imported task went back to external when its date is cleared" do
        task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today + 2))
        create(:task_source, task:)
        send_to("/admin/tasks/#{task.id}/schedule", sprint_on: "")
        follow_redirect!

        expect(page).to have_css("[data-toast] .toast", text: "Unscheduled · back in external", visible: :all)
      end

      it "pulls a task out of next onto a planned sprint" do
        sprint = create(:sprint, sprint_date: tomorrow)
        task = create(:task, title: "Email the accountant")
        send_to("/admin/tasks/#{task.id}/schedule", sprint_on: tomorrow.iso8601)

        expect(repo.by_id(task.id).sprint_id).to eq(sprint.id)
      end

      it "keeps a task waiting on a planned sprint out of next" do
        create(:task, :in_sprint, sprint: create(:sprint, sprint_date: tomorrow), title: "Tomorrow's work")
        get "/admin/tasks", filter: "next"

        expect(titles).to be_empty
      end

      it "drops the trailing space before the mark on a pull chip" do
        create(:sprint, sprint_date: tomorrow)
        create(:task, title: "#{'a' * 41} bbb")
        upcoming

        expect(page).to have_css(".sprint-chips .chip-btn span", exact_text: "#{'a' * 41}…")
      end

      it "keeps a family emoji whole where it cuts a pull chip" do
        create(:sprint, sprint_date: tomorrow)
        create(:task, title: "#{'a' * 41}👩‍👩‍👧‍👦 x")
        upcoming

        expect(page).to have_css(".sprint-chips .chip-btn span", exact_text: "#{'a' * 41}👩‍👩‍👧‍👦…")
      end

      it "marks the day a waiting task is scheduled for on its row" do
        create(:task, :in_sprint, sprint: create(:sprint, sprint_date: tomorrow))
        upcoming

        expect(page).to have_css(".task-meta .pill.orange", text: tomorrow.strftime("%b %-d"))
      end

      it "schedules a task from its editor" do
        task = create(:task)
        send_to("/admin/tasks/#{task.id}", filter: "next", task: { title: task.title, sprint_on: tomorrow.iso8601 })

        expect(repo.by_id(task.id).sprint_id).to eq(sprint_repo.on(tomorrow).id)
      end

      it "refuses a date from the editor that the day has passed" do
        task = create(:task)
        edit(task, sprint_on: (today - 1).iso8601)

        expect(repo.by_id(task.id).sprint_id).to be_nil
      end

      it "says why it refused the date rather than saying the task was saved" do
        edit(create(:task), sprint_on: (today - 1).iso8601)
        follow_redirect!

        expect(page).to have_css("[data-toast] .toast", text: "A sprint opens on today", visible: :all)
      end

      it "says why it refused a captured task's date that the day has passed" do
        capture("Yesterday's work", filter: "next", sprint_on: (today - 1).iso8601)
        follow_redirect!

        expect(page).to have_css("[data-toast] .toast", text: "A sprint opens on today", visible: :all)
      end

      it "lands a captured task whose date was refused on the tab it is on" do
        capture("Yesterday's work", filter: "next", sprint_on: (today - 1).iso8601)

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=next")
      end

      it "keeps a captured task whose date was refused" do
        capture("Yesterday's work", filter: "next", sprint_on: (today - 1).iso8601)
        get "/admin/tasks", filter: "next"

        expect(titles).to include("Yesterday's work")
      end

      it "unschedules a task from its editor" do
        task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: tomorrow))
        send_to("/admin/tasks/#{task.id}", filter: "next", task: { title: task.title, sprint_on: "" })

        expect(repo.by_id(task.id)).to have_attributes(list: "next", sprint_id: nil)
      end

      it "leaves a someday task where it is when its editor carries no date" do
        task = create(:task, :someday)
        send_to("/admin/tasks/#{task.id}", filter: "someday", task: { title: task.title, sprint_on: "" })

        expect(repo.by_id(task.id).list).to eq("someday")
      end

      it "takes over a planned sprint when its day arrives" do
        sprint = create(:sprint, sprint_date: today)
        yesterday = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today - 1))
        get "/admin/tasks"

        expect(repo.by_id(yesterday.id).sprint_id).to eq(sprint.id)
      end
    end
  end

  describe "signed out" do
    let(:task) { create(:task, title: "Email the accountant") }

    it "keeps the list off the screen" do
      get "/admin/tasks"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end

    it "shows no task to anybody who has not signed in" do
      task
      get "/admin/tasks"

      expect(last_response.body).not_to include("Email the accountant")
    end

    {
      "" => {},
      "/complete" => {},
      "/delete" => {},
      "/move/someday" => {},
      "/reopen" => {},
      "/reorder/up" => {},
      "/start" => {},
      "/stop" => {},
    }.each_key do |suffix|
      it "writes nothing through POST /admin/tasks/:id#{suffix}" do
        id = task.id
        post "/admin/tasks/#{id}#{suffix}", task: { title: "Changed" }

        expect(repo.by_id(id)).to have_attributes(title: "Email the accountant", list: "next", status: "open")
      end
    end

    it "captures nothing" do
      post "/admin/tasks", task: { title: "Email the accountant" }

      expect(repo.in_list("next")).to be_empty
    end
  end
end
