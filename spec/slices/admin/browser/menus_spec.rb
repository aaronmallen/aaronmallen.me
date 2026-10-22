# frozen_string_literal: true

RSpec.describe "Admin context menus", type: :feature do
  def self.menus
    {
      "calendar.event_menu" => [:calendar_event, %r{/calendar/events/\d+/menu}],
      "clients.menu" => [:client, %r{/clients/\d+/menu}],
      "commits.menu" => [:commit, %r{/commits/\d+/menu}],
      "decisions.comment_menu" => [:decision_comment, %r{/decisions/\d+/comments/\d+/menu}],
      "decisions.menu" => [:decision, %r{/decisions/\d+/menu}],
      "files.menu" => [:file, %r{/files/\d+/menu}],
      "journal.menu" => [:journal_entry, %r{/journal/\d+/menu}],
      "links.menu" => [:link, %r{/links/\d+/menu}],
      "mail.bulk_menu" => [:mail_picked, %r{/mail/\d+/menu}],
      "mail.menu" => [:mail, %r{/mail/\d+/menu}],
      "notes.folder_menu" => [:note_folder, %r{/notes/folders/\d+/menu}],
      "notes.menu" => [:note, %r{/notes/\d+/menu}],
      "notes.root_menu" => [:notes_root, %r{/notes/menu}, ".nt-gh"],
      "people.menu" => [:person, %r{/contacts/\d+/menu}],
      "posts.bulk_menu" => [:posts_picked, %r{/posts/\d+/menu}, ".li-sub"],
      "posts.menu" => [:posts, %r{/posts/\d+/menu}, ".li-sub"],
      "projects.menu" => [:project, %r{/projects/\d+/menu}],
      "services.menu" => [:service, %r{/services/\w+/menu}],
      "settings.cron_entry_menu" => [:cron_entry, %r{/settings/jobs/cron/\w+/menu}],
      "settings.set_job_menu" => [:set_job, %r{/settings/jobs/\w+/[0-9a-f]+/menu}, ".jobs-args"],
      "social.menu" => [:social_post, %r{/social/\d+/menu}],
      "sprints.menu" => [:sprint, %r{/tasks/sprints/\d+/menu}],
      "tags.menu" => [:tag, %r{/tags/\d+/menu}],
      "task_rules.menu" => [:task_rule, %r{/tasks/rules/\d+/menu}],
      "tasks.bulk_menu" => [:tasks_picked, %r{/tasks/\d+/menu}, ".record-key"],
      "tasks.comment_menu" => [:task_comment, %r{/tasks/\d+/comments/\d+/menu}],
      "tasks.menu" => [:tasks, %r{/tasks/\d+/menu}, ".record-key"],
      "tasks.session_menu" => [:work_session, %r{/tasks/\d+/sessions/\d+/menu}],
      "today.attention_menu" => [:attention, %r{/attention/menu}],
      "tokens.menu" => [:token, %r{/tokens/\d+/menu}],
      "webmentions.bulk_menu" => [:webmentions_picked, %r{/webmentions/\d+/menu}],
      "webmentions.menu" => [:webmentions, %r{/webmentions/\d+/menu}],
    }
  end

  def attention
    create(:task, carried_count: 4, title: "Carried task")
    visit "/admin"
  end

  def calendar_event
    connect_google(account_id: "me@example.com", scopes: Calendar::Operations::SyncCalendar::SCOPES)
    calendar = create(:calendar, account: "me@example.com", google_id: "me@example.com", name: "Aaron")
    create(:calendar_event, calendar_id: calendar.id, title: "Coffee", starts_on: today, ends_on: today,
                            starts_at: at(today, 9), ends_at: at(today, 10))
    visit "/admin/calendar?day=#{today.iso8601}"
  end

  def client
    create(:oauth_token, oauth_client: create(:oauth_client, client_name: "Desk"))
    visit "/admin/settings/services"
  end

  def commit
    create(:commit, commit_date: today, message: "add the view")
    visit "/admin"
    find(".commit", visible: :all).ancestor("details").find("summary").click
  end

  def cron_entry = visit("/admin/settings/jobs")

  def decision
    create(:decision, title: "Pick a queue")
    visit "/admin/decisions"
  end

  def decision_comment
    found = create(:decision)
    create(:decision_comment, decision_id: found.id, body: "Go with A")
    visit "/admin/decisions/#{found.id}"
  end

  def file
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
    upload_share
    visit "/admin/files"
  end

  def journal_entry
    create(:journal_entry, body: "shipped it")
    visit "/admin/journal"
  end

  def link
    Shares::Slice["operations.create_short_link"].call({ destination: "https://example.com/talk", title: "A talk" })
    visit "/admin/links"
  end

  def mail
    %w[Newer Older].each { create(:message, subject: it) }
    visit "/admin/mail"
  end

  def mail_picked
    mail
    click_button "Select"
    all(".mail-row input[name='ids[]']").each(&:check)
  end

  def note
    create(:note, title: "Plan")
    visit "/admin/notes"
  end

  def note_folder
    create(:note, folder_id: create(:note_folder, name: "work").id)
    visit "/admin/notes"
  end

  def notes_root = visit("/admin/notes")

  def open_menu(name)
    setup, pattern, target = self.class.menus.fetch(name)
    bulk = name.include?("bulk")
    send(setup)

    opened = right_click_row(pattern, target, picked: bulk)
    expect(opened).to have_css(".ctx-item")
    expect(opened).to have_css(".ctx-head", text: "picked") if bulk
  end

  def person
    create(:person, key: "matz")
    visit "/admin/contacts"
  end

  def posts
    %w[one two].each { create(:post, :draft, title: "#{it} draft") }
    visit "/admin/posts"
  end

  def posts_picked
    posts
    all("input[name='ids[]']").each(&:check)
  end

  def project
    create(:project, name: "Hanami")
    visit "/admin/projects"
  end

  def retries
    @retries ||= Spec::FakeJobSet.new("retry").tap do |set|
      set.add(Time.now, { "class" => "Social::Jobs::CrossPost", "args" => [42], "jid" => "abc123",
                          "queue" => "default", "error_class" => "Net::OpenTimeout", "error_message" => "timed out" })
    end
  end

  def right_click_row(pattern, target, picked:)
    row = evaluate_script(<<~JS, pattern.source, picked)
      [...document.querySelectorAll("[data-menu]")].find((row) =>
        new RegExp(arguments[0]).test(row.dataset.menu) &&
          (!arguments[1] || row.querySelector("input[name='ids[]']:checked")))
    JS
    scroll_to(row, align: :center)
    (target ? row.find(target) : row).right_click
    menu
  end

  def service
    Services::Slice["repos.connection_mutations"].add(
      provider: "linear", account_id: "a1", label: "Work", credentials: { api_key: "lin_api_secret" },
    )
    visit "/admin/settings/services"
  end

  def set_job
    stub_retries
    allow(Sidekiq::RetrySet).to receive(:new).and_return(retries)
    visit "/admin/settings/jobs"
  end

  def social_post
    create(:social_post, :scheduled)
    visit "/admin/social"
  end

  def sprint
    create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today + 2), title: "Plan ahead")
    visit "/admin/tasks?filter=upcoming"
  end

  def stub_retries
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([])
    allow(Sidekiq::Stats).to receive(:new).and_return(Spec::FakeStats.new(retry_size: 1))
    replace_component("sidekiq.set_jobs", ->(key, *, **) { key == "retry" ? retries.to_a : [] })
  end

  def tag
    create(:tag, name: "ruby")
    visit "/admin/settings/tagging"
  end

  def task_comment
    found = create(:task)
    create(:task_comment, task_id: found.id, body: "First try")
    visit "/admin/tasks/#{found.id}"
  end

  def task_rule
    Tasks::Slice["operations.save_task_rule"].call({ pattern: "aaronmallen/*", tags: "ruby" })
    visit "/admin/settings/tagging"
  end

  def tasks
    %w[first second].each { create(:task, title: it) }
    visit "/admin/tasks?filter=next"
  end

  def tasks_picked
    tasks
    click_button "Select"
    all("input[name='ids[]']").each(&:check)
  end

  def today = Blog::TimeZone.today

  def token
    API::Slice["operations.mint_token"].call(name: "Terminal")
    visit "/admin/settings/services"
  end

  def webmentions
    target = create(:post, :published)
    %w[Ada Grace].each { create(:webmention, post_id: target.id, author_name: it) }
    visit "/admin/webmentions"
  end

  def webmentions_picked
    webmentions
    all("input[name='ids[]']").each(&:check)
  end

  def work_session
    found = create(:task)
    create(:work_session, :closed, task_id: found.id)
    visit "/admin/tasks/#{found.id}"
  end

  before { sign_in_to_admin }

  menus.keys.product(%w[light dark]).each do |name, scheme|
    it "passes axe on #{name} in #{scheme} mode" do
      emulate_color_scheme(scheme)
      open_menu(name)

      expect(axe_breaches).to be_empty
    end
  end
end
