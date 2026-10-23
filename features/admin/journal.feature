Feature: Admin journal
  The journal page holds a composer beside the entries, grouped by day with the newest day first, and a search
  that narrows them by text or tag. The public site never shows an entry.

  Background:
    Given I am signed in to the admin

  Scenario: The empty journal draws the page head, the search and the composer
    When I visit "/admin/journal"
    Then the journal page shows ".screen-tab[aria-current='page']" reading "journal"
    And the journal page holds "#command-palette-journal i.fa-feather"
    And the journal page shows ".page-head h1" reading "Journal"
    And the journal page holds ".page-head-sub i.fa-lock:first-child"
    And the journal page holds ".g-main.rev > form#journal-entry.journal-compose + .journal-days"
    And the journal page holds ".page-head-actions form[role='search'] input#journal-search[name='q']"
    And the journal page holds "form[role='search'][data-autosubmit] label.sr-only[for='journal-search']"
    And the journal page holds ".screen-tabs-side .saved-views"
    And the journal page holds "form[method='get'][action='/admin/journal'] input[type='search'][name='q']"
    And the journal page holds "input#journal-search[placeholder='grep entries…']"
    And the journal field "Search" holds ""
    And the journal page shows ".empty" reading "Nothing written yet."
    And the journal page shows ".page-head-sub" holding "wrote on 0 of the last 30 days"
    And the journal page holds "#command-palette-create-journal-entry[data-palette-href='/admin/journal?write=1']"

  Scenario: The composer starts on today with an empty entry and a disabled Save
    When I visit "/admin/journal"
    Then the journal field "Entry date" holds "{today}"
    And the journal page holds "input#journal-entry-date[type='date'][max='{today}']"
    And the journal page holds "input[name='entry[entry_date]'][form='journal-entry']"
    And the journal page holds "form#journal-entry[method='post'][action='/admin/journal']"
    And the journal page holds "form#journal-entry input[name='_csrf_token'][type='hidden']"
    And the journal page shows "#journal-entry h2.card-title" reading "Today"
    And the journal page holds "#journal-entry[data-today='{today}'][data-today-label='Today']"
    And the journal field "Entry" holds ""
    And the journal page holds "textarea#journal-body[placeholder='Unfiltered. Nobody is reading this but you.']"
    And the journal page holds "#journal-entry [data-markdown-editor][style='--edit-height: 240px'] textarea[name='entry[body]']"
    And the journal page holds "#journal-entry [data-editor-preview='/admin/markdown/preview/posts']"
    And the journal page shows "#journal-entry .jbox-foot [data-journal-words]" reading "0 words"
    And the journal page holds "#journal-entry .jbox-foot input[type='date'][name='entry[entry_date]']"
    And the journal page holds "#journal-entry .jbox-foot input[name='entry[tags]']"
    And the journal page holds "[data-journal-words][data-one='%{count} word'][data-other='%{count} words']"
    And the journal button "Save entry" is disabled
    And the journal page holds "#journal-entry button[data-journal-save] i.fa-feather"
    And the journal page lacks "#journal-entry textarea[name='entry[body]'][autofocus]"

  Scenario: Opening the journal to write focuses the entry field
    When I visit "/admin/journal?write=1"
    Then the journal page holds "#journal-entry textarea[name='entry[body]'][autofocus]"

  Scenario: The sub-line counts every entry and word and the days written of the last 30
    Given the journal holds:
      | body          | day         |
      | one two three | {today}     |
      | four          | {today-40}  |
    When I visit "/admin/journal"
    Then the journal page shows ".page-head-sub" reading "Private · never shown on the public site · 2 entries · 4 words · wrote on 1 of the last 30 days"

  Scenario: The sub-line counts one entry and one word in the singular
    Given the journal holds:
      | body |
      | one  |
    When I visit "/admin/journal"
    Then the journal page shows ".page-head-sub" holding "1 entry · 1 word"

  Scenario: The streak counts the days written of the last 30, today included
    Given the journal holds:
      | body   | day        |
      | first  | {today}    |
      | second | {today}    |
      | edge   | {today-29} |
      | gone   | {today-30} |
    When I visit "/admin/journal"
    Then the journal page shows ".page-head-sub" holding "wrote on 2 of the last 30 days"

  Scenario: Entries group by day, newest day first, under a full date anchored by the day
    Given the journal holds:
      | body  | day        |
      | older | {today-3}  |
      | newer | {today}    |
      | fixed | 2026-09-03 |
    When I visit "/admin/journal"
    Then the journal shows the days "{today}, {today-3}, 2026-09-03"
    And the journal page shows "h2.day-head time.day-date[datetime='2026-09-03']" reading "Thursday, September 3, 2026"
    And the journal page holds "section.journal-day#day-2026-09-03 h2.day-head"

  Scenario Outline: A day heading says how long ago the day was
    Given the journal holds:
      | body   | day   |
      | walked | <day> |
    When I visit "/admin/journal"
    Then the journal page shows ".day-head .day-rule + .day-note" reading "<label>"

    Examples:
      | day       | label      |
      | {today}   | Today      |
      | {today-1} | Yesterday  |
      | {today-3} | 3 days ago |

  Scenario: An entry shows its time, its body and its markdown source
    Given the journal holds:
      | body           | time  | html             |
      | a **bold** day | 21:05 | <p>stored</p>    |
    When I visit "/admin/journal"
    Then the journal page shows ".journal-entry-head time" reading "21:05"
    And the journal entries read "stored"
    And the journal attribute "data-journal-source" of ".journal-entry" is "a **bold** day"

  Scenario: An entry counts its linked records and leaves the count off when it has none
    Given a post "On racks" published an hour ago
    And the journal holds:
      | body   |
      | walked |
      | sat    |
    And the journal entry "walked" links to the post "On racks"
    When I visit "/admin/journal"
    Then the journal page holds 1 of ".journal-linked"
    And the journal page shows ".journal-entry:has-text('walked') .journal-entry-head .journal-linked" reading "1 linked"

  Scenario: An entry shows its tags in their colours, linked to their summaries, and none as a pill
    Given the private tag "health" is coloured "mk-green"
    And the private tag "ruby" is coloured "mk-violet"
    And the journal holds:
      | body   | tags         |
      | walked | health, ruby |
    When I visit "/admin/journal"
    Then the journal texts of ".journal-entry-head .tag.green, .journal-entry-head .tag.violet" read "#health | #ruby"
    And the journal page holds "a[href='/admin/tags/health']:has-text('#health')"
    And the journal page lacks ".journal-entry-head .pill"
    And the journal attribute "data-journal-tags" of ".journal-entry" is "health, ruby"

  Scenario: A saved entry renders its markdown and drops raw HTML
    When I post the journal form to "/admin/journal" with:
      | entry[body]       | a **bold** day\n\n- one\n- two\n\n[the lake](https://example.com/lake)\n\n<script>alert(1)</script>\n\nsafe <b onclick="alert(1)">text</b> |
      | entry[entry_date] | {today}                                                                                                                       |
    Then the journal page shows ".journal-entry-body strong" reading "bold"
    And the journal texts of ".journal-entry-body ul li" read "one | two"
    And the journal page holds ".journal-entry-body a[href='https://example.com/lake']:has-text('the lake')"
    And the journal page lacks ".journal-entry-body script, .journal-entry-body b, .journal-entry-body [onclick]"
    And the database answers "false" for:
      """
      select body_html like '%alert%' from journal_entries
      """

  Scenario: A saved entry joins lines split by one newline and splits paragraphs at a blank line
    When I post the journal form to "/admin/journal" with:
      | entry[body] | first\nsecond\n\nthird |
    Then the journal texts of ".journal-entry-body p" read "first\nsecond | third"

  Scenario: Searching narrows entries by text, ignoring case, and keeps the search
    Given the journal holds:
      | body                     |
      | Rode my BIKE to the lake |
      | Stayed in                |
    When I visit "/admin/journal?q=bike"
    Then the journal entries read "Rode my BIKE to the lake"
    And the journal field "Search" holds "bike"
    And the journal page shows ".page-head-sub" holding "2 entries"

  Scenario: Searching says when nothing matches
    Given the journal holds:
      | body      |
      | Stayed in |
    When I visit "/admin/journal?q=swim"
    Then the journal page shows ".empty" reading "No entries match."

  Scenario: A search that isn't text lists every entry
    Given the journal holds:
      | body                     |
      | Rode my BIKE to the lake |
      | Stayed in                |
    When I visit "/admin/journal?q[nested]=bike"
    Then the journal entries read "Rode my BIKE to the lake | Stayed in" in any order

  Scenario: Searching by tag narrows entries to those that carry every tag, read in any case
    Given the journal holds:
      | body            | tags          |
      | Rode to work    | bike, commute |
      | Fixed a flat    | bike          |
      | Wrote some ruby | ruby          |
    When I visit "/admin/journal?q=tag:bike"
    Then the journal entries read "Rode to work | Fixed a flat" in any order
    When I visit "/admin/journal?q=tag:BIKE"
    Then the journal entries read "Rode to work | Fixed a flat" in any order
    When I visit "/admin/journal?q=tag:bike%20tag:commute"
    Then the journal entries read "Rode to work"

  Scenario: Searching by tag searches the words beside the tag as text and keeps the query
    Given the journal holds:
      | body         | tags          |
      | Rode to work | bike, commute |
      | Fixed a flat | bike          |
    When I visit "/admin/journal?q=tag:bike%20flat"
    Then the journal entries read "Fixed a flat"
    And the journal field "Search" holds "tag:bike flat"

  Scenario: Searching by a tag no entry carries says nothing matches
    Given the journal holds:
      | body         | tags |
      | Fixed a flat | bike |
    When I visit "/admin/journal?q=tag:swim"
    Then the journal page shows ".empty" reading "No entries match."

  Scenario: Each entry puts Edit and Delete in its header and posts the delete with a token and a question
    Given the journal holds:
      | body   |
      | walked |
    When I visit "/admin/journal"
    Then the journal page holds ".journal-entry-head .journal-entry-actions button.bt[type='button'][data-journal-edit]"
    And the journal page holds ".journal-entry-head .journal-entry-actions form button.warn[type='submit']"
    And the journal attribute "data-confirm" of "form[action='/admin/journal/1/delete'][method='post']" is "Delete this entry? You can't undo this."
    And the journal page holds "form[action='/admin/journal/1/delete'] input[name='_csrf_token'][type='hidden']"
    And the journal attribute "data-journal-scope" of ".journal-entry" is "journal-edit-1"
    And the journal attribute "data-journal-update" of ".journal-entry" is "/admin/journal/1"

  Scenario: Each entry leaves its edit form to one template the script fills
    Given the journal holds:
      | body   |
      | walked |
    When I visit "/admin/journal"
    Then the journal page lacks "form[action='/admin/journal/1']"
    And the journal page holds 1 of "template[data-journal-edit-template='journal-edit-template']"
    And the journal edit template holds "form[method='post'][data-journal-edit-form] input[name='_csrf_token'][type='hidden']"
    And the journal edit template holds "form[data-journal-edit-form] [data-markdown-editor][style='--edit-height: 200px'] textarea#journal-edit-template-body[name='entry[body]']"
    And the journal edit template holds "form[data-journal-edit-form] button[type='submit'][disabled]"
    And the journal edit template holds "form[data-journal-edit-form] button[type='button'][data-journal-cancel]"

  Scenario: A tagged entry opened to edit draws one edit form holding its text and tags
    Given the journal holds:
      | body | tags         |
      | read | ruby, health |
    When I visit "/admin/journal?edit=1"
    Then the journal page holds 1 of "form[data-journal-edit-form]"
    And the journal page holds "form[action='/admin/journal/1'][data-journal-source='read']"
    And the journal field "Entry text" holds "read"
    And the journal page holds "form[action='/admin/journal/1'] input[name='entry[tags]'][value='health, ruby']"

  Scenario: The quick-write modal on every page starts closed, posting to the journal and coming back
    When I visit "/admin/analytics"
    Then the journal page holds "dialog#journal-write:not([data-dialog-show]) form[action='/admin/journal']"
    And the journal page holds "dialog#journal-write form input[name='return_to'][value='/admin/analytics']"

  Scenario: The quick-write modal names the key that saves it
    When I visit "/admin/posts"
    Then the journal page shows "dialog#journal-write .journal-modal-hint" reading "⌘↵ save"

  Scenario Outline: The public site shows no journal entry on <path>
    Given the journal holds:
      | body                   | tags |
      | a private journal line | ruby |
    And a post "hello" published an hour ago
    And the database runs:
      """
      insert into tags (name, color, scope) values ('ruby', 'mk-pink', 'public');
      insert into post_tags (post_id, tag_id) select 1, id from tags where scope = 'public';
      """
    Then the public page "<path>" answers 200 without "a private journal line"

    Examples:
      | path                    |
      | /                       |
      | /writing                |
      | /writing/hello          |
      | /writing/tags/ruby      |
      | /writing.atom           |
      | /writing/tags/ruby.atom |
      | /about                  |
      | /projects               |
      | /contact                |

  Scenario Outline: The journal's pages have no axe breaches on <path>
    Given the journal holds:
      | body   | tags   |
      | walked | health |
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path                          |
      | /admin/journal                |
      | /admin/journal?edit=1         |
      | /admin/journal?q=swim         |
      | /admin/journal?write=1        |
      | /admin/posts                  |
      | /admin/analytics              |
