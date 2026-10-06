# frozen_string_literal: true

RSpec.describe "Admin journal", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:i18n) { Admin::Slice["i18n"] }
  let(:repo) { Record::Slice["repos.journal_entry_repo"] }
  let(:today) { Blog::TimeZone.today }
  let(:toast) { page.find("[data-toast] .toast", visible: :all).text(:all) }

  def bodies = page.all(".journal-entry-body").map(&:text)

  def day_bodies(date) = page.all(".journal-day:has(time[datetime='#{date.iso8601}']) .journal-entry-body").map(&:text)

  def day_dates = page.all(".day-date").map { it["datetime"] }

  def entries = repo.between(from: today - 30, to: today)

  def entry = entries.first

  def save(**fields)
    post "/admin/journal", _csrf_token: admin_csrf_token, entry: fields
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the page" do
      before { get "/admin/journal" }

      it "says journal is where you are" do
        expect(page).to have_css(".ctx-where", text: %r{Daily\s+/\s+journal})
      end

      it "shows the feather icon in the palette" do
        expect(page).to have_css("#command-palette-journal i.fa-feather", visible: :all)
      end

      it "renders the heading" do
        expect(page).to have_css(".page-head h1", text: "Journal")
      end

      it "puts a lock before the sub-line" do
        expect(page).to have_css(".page-head-sub i.fa-lock:first-child")
      end

      it "lays out the filters beside the content" do
        expect(page).to have_css(".split > .journal-rail + .journal-main")
      end

      it "searches with a get form" do
        expect(page).to have_css("form[method='get'][action='/admin/journal'] input[type='search'][name='q']")
      end

      it "labels the search with its placeholder" do
        expect(page).to have_field("Search", placeholder: "grep entries…")
      end

      it "defaults the entry date to today" do
        expect(page).to have_field("Entry date", type: "date", with: today.iso8601)
      end

      it "stops the entry date at today" do
        expect(page).to have_css("#journal-entry-date[max='#{today.iso8601}']")
      end

      it "sends the entry date with the new entry" do
        expect(page).to have_css("input[name='entry[entry_date]'][form='journal-entry']")
      end

      it "posts the new entry form with the CSRF token", :aggregate_failures do
        expect(page).to have_css("form#journal-entry[method='post'][action='/admin/journal']")
        expect(page).to have_css("form#journal-entry input[name='_csrf_token']", visible: :hidden)
      end

      it "titles the new entry card Today" do
        expect(page).to have_css("#journal-entry h2.card-title", exact_text: "Today")
      end

      it "gives the script today and its label" do
        expect(page).to have_css("#journal-entry[data-today='#{today.iso8601}'][data-today-label='Today']")
      end

      it "renders the entry textarea" do
        expect(page).to have_field("Entry", type: "textarea", with: "",
                                            placeholder: "Unfiltered. Nobody is reading this but you.")
      end

      it "draws the entry in the Markdown editor at its own height" do
        expect(page).to have_css(
          "#journal-entry [data-markdown-editor][style='--edit-height: 240px'] textarea[name='entry[body]']",
        )
      end

      it "previews the entry through the post renderer" do
        expect(page).to have_css(
          "#journal-entry [data-editor-preview='/admin/markdown/preview/posts']", visible: :hidden,
        )
      end

      it "shows the word count in the card head" do
        expect(page).to have_css("#journal-entry .card-side [data-journal-words]", exact_text: "0 words")
      end

      it "gives the script the word templates" do
        words = page.find("[data-journal-words]")

        expect([words["data-one"], words["data-other"]]).to eq(i18n.t("ui.components.journal.new_entry.words").values)
      end

      it "disables Save entry while the entry is empty" do
        expect(page).to have_button("Save entry", disabled: true)
      end

      it "shows an empty state without entries" do
        expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.journal.index.empty"))
      end

      it "shows the streak with no days" do
        expect(page).to have_css(".journal-streak", exact_text: "Wrote on 0 of the last 30 days")
      end

      it "leaves the entry field unfocused" do
        expect(page).to have_no_css("textarea[name='entry[body]'][autofocus]")
      end

      it "offers a palette row that opens the page ready to write" do
        expect(page).to have_css(
          "#command-palette-create-journal-entry[data-palette-href='/admin/journal?write=1']", visible: :all,
        )
      end
    end

    describe "the page, opened to write" do
      before { get "/admin/journal", write: "1" }

      it "focuses the entry field" do
        expect(page).to have_css("#journal-entry textarea[name='entry[body]'][autofocus]")
      end
    end

    describe "with entries" do
      it "counts every entry and word in the sub-line" do
        create(:journal_entry, body: "one two three")
        create(:journal_entry, body: "four", entry_date: today - 40)
        get "/admin/journal"

        sub = "Private · never rendered on the public site · 2 entries · 4 words"

        expect(page).to have_css(".page-head-sub", exact_text: sub)
      end

      it "counts one entry and one word" do
        create(:journal_entry, body: "one")
        get "/admin/journal"

        expect(page).to have_css(".page-head-sub", text: "1 entry · 1 word")
      end

      it "groups entries by day, newest day first" do
        create(:journal_entry, entry_date: today - 3, body: "older")
        create(:journal_entry, entry_date: today, body: "newer")
        get "/admin/journal"

        expect(day_dates).to eq([today.iso8601, (today - 3).iso8601])
      end

      it "shows the full date in each day heading" do
        create(:journal_entry, entry_date: Date.new(2026, 9, 3))
        get "/admin/journal"

        expect(page).to have_css("h2.day-head time.day-date", exact_text: "Thursday, September 3, 2026")
      end

      it "anchors each day by its date" do
        create(:journal_entry, entry_date: Date.new(2026, 9, 3))
        get "/admin/journal"

        expect(page).to have_css("section.journal-day#day-2026-09-03 h2.day-head")
      end

      { 0 => "Today", 1 => "Yesterday", 3 => "3 days ago" }.each do |days, label|
        it "labels a day #{days} days back #{label}" do
          create(:journal_entry, entry_date: today - days)
          get "/admin/journal"

          expect(page).to have_css(".day-head .day-rule + .day-note", exact_text: label)
        end
      end

      it "shows each entry's time and body", :aggregate_failures do
        create(:journal_entry, entry_time: "21:05", body: "walked")
        get "/admin/journal"

        expect(page).to have_css(".journal-entry-head time", exact_text: "21:05")
        expect(bodies).to eq(["walked"])
      end

      it "shows each tag as its name in the colour its tag carries" do
        %w[mk-green mk-violet].zip(%w[health ruby]) { |color, name| create(:tag, :private, name:, color:) }
        create(:journal_entry, body: "walked", tags: %w[health ruby])
        get "/admin/journal"

        expect(page.all(".journal-entry-head .tag.green, .journal-entry-head .tag.violet").map(&:text))
          .to eq(%w[#health #ruby])
      end

      it "links each tag to the journal searched by that tag" do
        create(:journal_entry, body: "walked", tags: %w[health])
        get "/admin/journal"

        expect(page).to have_link("#health", href: "/admin/journal?q=tag:health")
      end

      it "shows no tag as a pill" do
        create(:journal_entry, body: "walked", tags: %w[health ruby])
        get "/admin/journal"

        expect(page).to have_no_css(".journal-entry-head .pill")
      end

      it "renders the body as markdown", :aggregate_failures do
        create(:journal_entry, body: "a **bold** day\n\n- one\n- two\n\n[the lake](https://example.com/lake)")
        get "/admin/journal"

        expect(page).to have_css(".journal-entry-body strong", exact_text: "bold")
        expect(page.all(".journal-entry-body ul li").map(&:text)).to eq(%w[one two])
        expect(page).to have_link("the lake", href: "https://example.com/lake")
      end

      it "joins lines split by one newline into one paragraph" do
        create(:journal_entry, body: "first\nsecond")
        get "/admin/journal"

        expect(page.all(".journal-entry-body p").map(&:text)).to eq(["first\nsecond"])
      end

      it "starts a new paragraph after a blank line" do
        create(:journal_entry, body: "first\n\nsecond")
        get "/admin/journal"

        expect(page.all(".journal-entry-body p").map(&:text)).to eq(%w[first second])
      end

      it "drops raw HTML from a body", :aggregate_failures do
        create(:journal_entry, body: "<script>alert(1)</script>\n\nsafe <b onclick=\"alert(1)\">text</b>")
        get "/admin/journal"

        expect(page).to have_no_css(".journal-entry-body script, .journal-entry-body b, .journal-entry-body [onclick]")
        expect(page.find(".journal-entry-body").native.inner_html).not_to include("alert")
      end

      it "gives the edit form the markdown source" do
        create(:journal_entry, body: "a **bold** day")
        get "/admin/journal"

        expect(page).to have_css("[data-journal-edit-form][data-journal-source='a **bold** day']", visible: :all)
      end

      it "counts the streak over the last 30 days, today included" do
        2.times { create(:journal_entry, entry_date: today) }
        create(:journal_entry, entry_date: today - 29)
        create(:journal_entry, entry_date: today - 30)
        get "/admin/journal"

        expect(page).to have_css(".journal-streak", exact_text: "Wrote on 2 of the last 30 days")
      end
    end

    describe "searching" do
      before do
        create(:journal_entry, body: "Rode my BIKE to the lake")
        create(:journal_entry, body: "Stayed in")
      end

      it "narrows entries by text, ignoring case" do
        get "/admin/journal", q: "bike"

        expect(bodies).to eq(["Rode my BIKE to the lake"])
      end

      it "keeps the search in the field" do
        get "/admin/journal", q: "bike"

        expect(page).to have_field("Search", with: "bike")
      end

      it "counts every entry in the sub-line while searching" do
        get "/admin/journal", q: "bike"

        expect(page).to have_css(".page-head-sub", text: "2 entries")
      end

      it "says when nothing matches" do
        get "/admin/journal", q: "swim"

        expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.journal.index.no_match"))
      end

      it "lists every entry for a search that isn't text" do
        get "/admin/journal", q: { nested: "bike" }

        expect(bodies.size).to eq(2)
      end
    end

    describe "searching by tag" do
      before do
        create(:journal_entry, body: "Rode to work", tags: %w[bike commute])
        create(:journal_entry, body: "Fixed a flat", tags: %w[bike])
        create(:journal_entry, body: "Wrote some ruby", tags: %w[ruby])
      end

      it "narrows entries to the tag" do
        get "/admin/journal", q: "tag:bike"

        expect(bodies).to contain_exactly("Rode to work", "Fixed a flat")
      end

      it "reads the tag in any case" do
        get "/admin/journal", q: "tag:BIKE"

        expect(bodies).to contain_exactly("Rode to work", "Fixed a flat")
      end

      it "narrows to entries that carry every tag" do
        get "/admin/journal", q: "tag:bike tag:commute"

        expect(bodies).to eq(["Rode to work"])
      end

      it "searches the words beside the tag as text" do
        get "/admin/journal", q: "tag:bike flat"

        expect(bodies).to eq(["Fixed a flat"])
      end

      it "keeps the query in the field" do
        get "/admin/journal", q: "tag:bike flat"

        expect(page).to have_field("Search", with: "tag:bike flat")
      end

      it "says when no entry carries the tag" do
        get "/admin/journal", q: "tag:swim"

        expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.journal.index.no_match"))
      end
    end

    describe "paging" do
      def pager_href(rel) = page.find("nav.pager a[rel='#{rel}']")["href"]

      before do
        lower_page_size(:admin, to: 2)
        { 0 => 1, 1 => 2, 2 => 1, 3 => 1, 5 => 1 }.each do |days, count|
          count.times { |index| create(:journal_entry, entry_date: today - days, body: "d#{days}e#{index}") }
        end
      end

      it "stops near the page size and finishes the day it is on" do
        get "/admin/journal"

        expect(day_dates).to eq([today, today - 1].map(&:iso8601))
      end

      it "shows every entry of the last day on the page" do
        get "/admin/journal"

        expect(day_bodies(today - 1)).to contain_exactly("d1e0", "d1e1")
      end

      it "links to older entries from the first page", :aggregate_failures do
        get "/admin/journal"

        expect(pager_href("next")).to eq("/admin/journal?to=#{(today - 2).iso8601}")
        expect(page).to have_no_css("nav.pager a[rel='prev']")
      end

      it "shows the older days behind the link" do
        get "/admin/journal", to: (today - 2).iso8601

        expect(day_dates).to eq([today - 2, today - 3].map(&:iso8601))
      end

      it "links back to the newest page when a page or less is newer" do
        get "/admin/journal", to: (today - 1).iso8601

        expect(pager_href("prev")).to eq("/admin/journal")
      end

      it "links back a page's worth of entries when more are newer" do
        get "/admin/journal", to: (today - 2).iso8601

        expect(pager_href("prev")).to eq("/admin/journal?to=#{(today - 1).iso8601}")
      end

      it "links to no older page from the oldest day", :aggregate_failures do
        get "/admin/journal", to: (today - 5).iso8601

        expect(day_dates).to eq([(today - 5).iso8601])
        expect(page).to have_no_css("nav.pager a[rel='next']")
      end

      it "keeps the search in the links" do
        get "/admin/journal", q: "d"

        expect(pager_href("next")).to eq("/admin/journal?q=d&to=#{(today - 2).iso8601}")
      end

      it "pages the entries a search finds" do
        get "/admin/journal", q: "e1"

        expect(bodies).to eq(["d1e1"])
      end

      it "counts every entry and word in the sub-line" do
        get "/admin/journal"

        expect(page).to have_css(".page-head-sub", text: "6 entries · 6 words")
      end

      it "counts the streak over every entry" do
        get "/admin/journal"

        expect(page).to have_css(".journal-streak", exact_text: "Wrote on 5 of the last 30 days")
      end

      it "reads a day it can't parse as the newest page" do
        get "/admin/journal", to: "soon"

        expect(day_dates).to eq([today, today - 1].map(&:iso8601))
      end

      %w[99999999-01-01 -4800-01-01].each do |date|
        it "reads a day of #{date} as the newest page" do
          get "/admin/journal", to: date

          expect(day_dates).to eq([today, today - 1].map(&:iso8601))
        end
      end

      it "draws no pager when one page holds every entry" do
        lower_page_size(:admin, to: 10)
        get "/admin/journal"

        expect(page).to have_no_css("nav.pager")
      end
    end

    describe "paging newer past a crowded day" do
      def days_newer_from(href)
        get href
        seen = day_dates
        seen |= day_dates while follow("prev")
        seen
      end

      def follow(rel)
        return false unless page.has_css?("nav.pager a[rel='#{rel}']")

        get(pager_href(rel))
      end

      def older_pages
        get "/admin/journal"
        hrefs = []
        hrefs << last_request.fullpath while follow("next")
        hrefs
      end

      def page = Capybara.string(last_response.body)

      def pager_href(rel) = page.find("nav.pager a[rel='#{rel}']")["href"]

      def round_trip(href)
        get href
        follow("prev")
        follow("next")
        last_request.fullpath
      end

      before do
        lower_page_size(:admin, to: 2)
        { 0 => 1, 1 => 3, 2 => 1, 3 => 2, 4 => 1, 6 => 1 }.each do |days, count|
          count.times { |index| create(:journal_entry, entry_date: today - days, body: "d#{days}e#{index}") }
        end
      end

      it "returns to each older page after paging newer then older" do
        expect(older_pages.map { round_trip(it) }).to eq(older_pages)
      end

      it "shows every day while paging newer from the oldest page" do
        expect(days_newer_from(older_pages.last).sort).to eq([0, 1, 2, 3, 4, 6].map { (today - it).iso8601 }.sort)
      end

      it "shows the next day when the day past it fills a page" do
        get "/admin/journal", to: (today - 3).iso8601
        follow("prev")

        expect(day_dates).to eq([today - 2, today - 3].map(&:iso8601))
      end
    end

    describe "saving an entry" do
      it "saves it under today with the time of saving", :aggregate_failures do
        save(body: "walked", entry_date: today.iso8601)
        entry = repo.today.first

        expect(entry).to have_attributes(body: "walked", entry_date: today)
        expect(entry.entry_time.strftime("%H:%M:%S")).to eq(Blog::TimeZone.local(now).strftime("%H:%M:%S"))
      end

      it "returns to the journal with the toast", :aggregate_failures do
        save(body: "walked", entry_date: today.iso8601)
        follow_redirect!

        expect(last_request.path).to eq("/admin/journal")
        expect(toast).to eq("Journal entry saved · private")
      end

      it "lists the new entry under its day" do
        save(body: "walked", entry_date: today.iso8601)
        follow_redirect!

        expect(day_bodies(today)).to eq(["walked"])
      end

      it "files a backdated entry under the chosen date with the time of saving", :aggregate_failures do
        save(body: "remembered", entry_date: (today - 4).iso8601)
        entry = entries.find { it.entry_date == today - 4 }

        expect(entry.body).to eq("remembered")
        expect(entry.entry_time.strftime("%H:%M:%S")).to eq(Blog::TimeZone.local(now).strftime("%H:%M:%S"))
      end

      it "saves under today without an entry date" do
        save(body: "walked")

        expect(entries.map(&:entry_date)).to eq([today])
      end

      it "saves the tags, folded to one case" do
        save(body: "walked", entry_date: today.iso8601, tags: "Ruby, health")

        expect(entry.tags.map(&:name)).to eq(%w[health ruby])
      end

      it "saves an entry with no tags" do
        save(body: "walked", entry_date: today.iso8601)

        expect(entry.tags).to eq([])
      end
    end

    describe "invalid input" do
      def message(key) = i18n.t(key, scope: "ui.components.journal.field_error")

      it "answers 422 and saves nothing for a blank entry" do
        save(body: " \n ", entry_date: today.iso8601)

        expect([last_response.status, repo.count]).to eq([422, 0])
      end

      it "shows the body error next to the textarea", :aggregate_failures do
        save(body: "  ", entry_date: today.iso8601)

        expect(page).to have_css("#journal-body-error.field-error", exact_text: message("body.blank"))
        expect(page).to have_css("#journal-body[aria-invalid='true'][aria-describedby='journal-body-error']")
      end

      it "rejects a future date and keeps what was typed", :aggregate_failures do
        save(body: "tomorrow", entry_date: (today + 1).iso8601)

        expect(page).to have_css("#journal-entry-date-error", exact_text: message("entry_date.future"))
        expect(page).to have_field("Entry", with: "tomorrow")
        expect(repo.count).to eq(0)
      end

      it "rejects a date it can't read" do
        save(body: "walked", entry_date: "2026-02-30")

        expect(page).to have_css("#journal-entry-date-error", exact_text: message("entry_date.format"))
      end

      it "rejects a tag it can't use and keeps what was typed", :aggregate_failures do
        save(body: "walked", entry_date: today.iso8601, tags: "a/b")

        expect(page).to have_css("#journal-tags-error", exact_text: message("tags.format"))
        expect(page).to have_field("Tags", with: "a/b")
        expect(repo.count).to eq(0)
      end

      it "keeps the chosen date and titles the card with it", :aggregate_failures do
        save(body: "", entry_date: "2026-09-03")

        expect(page).to have_field("Entry date", with: "2026-09-03")
        expect(page).to have_css("#journal-entry h2.card-title", exact_text: "Thursday, September 3, 2026")
      end

      it "rejects a save without a CSRF token" do
        post "/admin/journal", entry: { body: "walked" }

        expect([last_response.status, repo.count]).to eq([403, 0])
      end
    end

    describe "each entry" do
      before do
        create(:journal_entry, body: "walked")
        get "/admin/journal"
      end

      it "puts Edit and Delete in the entry's header", :aggregate_failures do
        actions = page.find(".journal-entry-head .journal-entry-actions")

        expect(actions).to have_button("Edit", type: "button", class: "btn", exact: true)
        expect(actions).to have_button("Delete", type: "submit", class: "warn", exact: true)
      end

      it "posts the delete form with the CSRF token and the confirmation", :aggregate_failures do
        form = page.find("form[action='/admin/journal/#{entry.id}/delete'][method='post']")

        expect(form["data-confirm"]).to eq(i18n.t("ui.components.journal.entry.confirm_delete"))
        expect(form).to have_field("_csrf_token", type: "hidden")
      end

      it "hides an edit form holding the entry's text", :aggregate_failures do
        form = page.find("form[action='/admin/journal/#{entry.id}'][method='post'][hidden]", visible: :hidden)

        expect(form).to have_field("Entry text", type: "textarea", with: "walked", visible: :hidden)
        expect(form).to have_field("_csrf_token", type: "hidden")
      end

      it "draws the edit form's text in the Markdown editor at its own height" do
        form = page.find("form[action='/admin/journal/#{entry.id}'][method='post']", visible: :hidden)

        expect(form).to have_css(
          "[data-markdown-editor][style='--edit-height: 200px'] textarea[name='entry[body]']", visible: :hidden,
        )
      end

      it "holds the entry's tags in the edit form, joined by commas" do
        create(:journal_entry, body: "read", tags: %w[ruby health])
        get "/admin/journal"
        form = page.find("form[action='/admin/journal/#{entry.id}']", visible: :hidden)

        expect(form).to have_field("Tags", with: "health, ruby", visible: :hidden)
      end

      it "gives the edit form Save and Cancel", :aggregate_failures do
        form = page.find("form[action='/admin/journal/#{entry.id}']", visible: :hidden)

        expect(form).to have_button("Save", type: "submit", visible: :hidden)
        expect(form).to have_button("Cancel", type: "button", visible: :hidden)
      end
    end

    describe "editing an entry" do
      before { create(:journal_entry, entry_date: today - 3, entry_time: "21:05", body: "before") }

      def edit(id = entry.id, **fields)
        post "/admin/journal/#{id}", _csrf_token: admin_csrf_token, entry: fields
      end

      it "changes the body and keeps the date and time", :aggregate_failures do
        edit(body: "after", entry_date: today.iso8601, entry_time: "08:00")
        saved = repo.by_id(entry.id)

        expect(saved).to have_attributes(body: "after", entry_date: today - 3)
        expect(saved.entry_time.strftime("%H:%M")).to eq("21:05")
      end

      it "changes the tags, folded to one case" do
        edit(body: "after", tags: "Ruby, Health")

        expect(repo.by_id(entry.id).tags.map(&:name)).to eq(%w[health ruby])
      end

      it "returns to the journal with the toast", :aggregate_failures do
        edit(body: "after")
        follow_redirect!

        expect(last_request.path).to eq("/admin/journal")
        expect(toast).to eq("Entry updated")
      end

      [" ", "", "\n\t "].each do |body|
        it "answers 422 and keeps the old body for #{body.inspect}" do
          edit(body:)

          expect([last_response.status, repo.by_id(entry.id).body]).to eq([422, "before"])
        end
      end

      it "reopens the edit form with the textarea marked invalid" do
        edit(body: "  ")
        id = "journal-edit-#{entry.id}-body"
        form = page.find("form[action='/admin/journal/#{entry.id}']:not([hidden])")

        expect(form).to have_css("textarea##{id}[aria-invalid='true'][aria-describedby='#{id}-error']")
      end

      it "shows the blank error under the textarea" do
        edit(body: "  ")

        message = i18n.t("ui.components.journal.field_error.body.blank")

        expect(page).to have_css("#journal-edit-#{entry.id}-body-error.field-error", exact_text: message)
      end

      it "hides the saved text while the edit form is open" do
        edit(body: "  ")

        expect(page).to have_css(".journal-entry-body[hidden]", visible: :hidden, exact_text: "before")
      end

      it "leaves the new entry form alone on a rejected edit" do
        edit(body: "  ")

        expect(page).to have_no_css("#journal-body-error")
      end

      it "rejects an edit without a CSRF token" do
        post "/admin/journal/#{entry.id}", entry: { body: "after" }

        expect([last_response.status, repo.by_id(entry.id).body]).to eq([403, "before"])
      end
    end

    describe "deleting an entry" do
      before { create(:journal_entry, body: "one two") }

      def delete_entry(id = entry.id) = post "/admin/journal/#{id}/delete", _csrf_token: admin_csrf_token

      it "removes the entry" do
        delete_entry

        expect(repo.count).to eq(0)
      end

      it "returns to the journal with the toast", :aggregate_failures do
        delete_entry
        follow_redirect!

        expect(last_request.path).to eq("/admin/journal")
        expect(toast).to eq("Entry deleted")
      end

      it "updates the counts and the streak", :aggregate_failures do
        create(:journal_entry, entry_date: today - 1, body: "three")
        delete_entry
        follow_redirect!

        expect(page).to have_css(".page-head-sub", text: "1 entry · 1 word")
        expect(page).to have_css(".journal-streak", exact_text: "Wrote on 1 of the last 30 days")
      end

      it "answers 404 for an entry that is gone" do
        delete_entry(entry.id + 1)

        expect([last_response.status, repo.count]).to eq([404, 1])
      end

      it "answers with a server error when the delete fails", :aggregate_failures do
        replace_component("record.operations.delete_journal_entry", ->(_id) { Dry::Monads::Failure(:unexpected) })
        delete_entry

        expect([last_response.status, repo.count]).to eq([500, 1])
        expect(last_response.headers["Location"]).to be_nil
      end

      it "rejects a delete without a CSRF token" do
        post "/admin/journal/#{entry.id}/delete"

        expect([last_response.status, repo.count]).to eq([403, 1])
      end

      it "deletes from the Delete button with scripts off", :aggregate_failures do
        browser = signed_in_browser
        browser.visit("/admin/journal")
        browser.find(".journal-entry-actions").click_button("Delete")

        expect(repo.count).to eq(0)
        expect(browser.find("[data-toast] .toast", visible: :all).text(:all)).to eq("Entry deleted")
      end

      def session_cookie = "#{Blog::SessionCookie::KEY}=#{Spec::AdminSession.cookie(csrf_token: admin_csrf_token)}"

      def signed_in_browser
        Capybara::Session.new(:rack_test, Hanami.app).tap do |browser|
          browser.driver.browser.set_cookie(session_cookie, URI(Capybara.default_host))
        end
      end
    end
  end

  describe "signed out" do
    it "redirects the journal to sign-in" do
      get "/admin/journal"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end

    it "saves nothing" do
      post "/admin/journal", entry: { body: "walked" }

      expect(repo.count).to eq(0)
    end

    it "changes nothing" do
      entry = create(:journal_entry, body: "before")
      post "/admin/journal/#{entry.id}", entry: { body: "after" }
      post "/admin/journal/#{entry.id}/delete"

      expect(repo.by_id(entry.id).body).to eq("before")
    end
  end

  describe "the public site" do
    before do
      create(:journal_entry, body: "a private journal line", tags: %w[ruby])
      create(:post, :published, slug: "hello", tags: %w[ruby])
    end

    %w[
      / /writing /writing/hello /writing/tags/ruby /writing.atom /writing/tags/ruby.atom /about /projects /contact
    ].each do |path|
      it "renders no journal entry on #{path}" do
        get path

        expect(last_response.body).not_to include("a private journal line")
      end
    end
  end
end
