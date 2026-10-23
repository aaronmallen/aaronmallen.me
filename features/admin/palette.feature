Feature: Admin command palette
  A slash, ⌘K or Ctrl+K opens the palette on any admin screen. It lists actions, saved views, every screen by its
  category and the records that match what I type, and runs the row I pick with the keys or a tap.

  Background:
    Given I am signed in to the admin
    And the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Email the accountant', 1, 'next');
      """
    And the contact form brings in "Hello"

  Scenario: The palette stays shut until something opens it, and the pills say where I am
    When I visit "/admin"
    Then the admin markup lacks "dialog#command-palette[open]"
    And the admin markup holds ".pill-nav-link[href='/admin/inbox'] .pill-nav-dot"
    When I visit "/admin/posts"
    Then the admin markup holds ".pill-nav-link[aria-current='page']:has-text('Publish')"
    And the admin markup holds ".screen-tab[aria-current='page']:has-text('posts')"

  Scenario: Opening it with the keyboard puts the cursor in the query box over every screen by category
    When I visit "/admin"
    And I press the keys "Meta+/"
    Then the admin markup holds "dialog#command-palette[open]"
    And the palette query box has the focus
    And the palette query box shows a ring
    And the palette query box stands at least 44px tall
    And the admin markup holds "[aria-labelledby='command-palette-group-inbox'] .pal-g:text-matches('inbox', 'i')"
    And the admin markup holds "[aria-labelledby='command-palette-group-inbox'] #command-palette-mail"
    And the admin markup holds "[aria-labelledby='command-palette-group-insights'] #command-palette-time"
    And the palette rows under "[aria-labelledby='command-palette-group-settings']" have the ids:
      | command-palette-webmention_settings |
      | command-palette-tagging             |
      | command-palette-services            |
      | command-palette-security            |
      | command-palette-jobs                |
    And the admin markup holds "[aria-labelledby='command-palette-group-journal'] #command-palette-journal[data-key='g j']"
    And the palette groups run:
      | actions     |
      | saved-views |
      | today       |
      | inbox       |
      | tasks       |
      | journal     |
      | publish     |
      | agents      |
      | insights    |
      | settings    |
      | records     |
      | see-all     |
    And the admin markup holds "#command-palette-create-task .pal-r-key:text-is('c')"
    And the admin markup holds "#command-palette-create-journal-entry .pal-r-key:text-is('w')"
    And the palette picks "command-palette-create-task"
    And the admin markup holds "[data-palette-query][aria-activedescendant='command-palette-create-task']"
    And the admin markup lacks "#command-palette-kind-task"
    And "#command-palette-create-task:has-text('Create task')" shows
    And "[aria-labelledby='command-palette-group-actions'] .pal-g:text-matches('actions', 'i')" shows
    And "[aria-labelledby='command-palette-group-actions'] #command-palette-create-journal-entry:has-text('Create journal entry')" shows
    And the admin markup lacks "#command-palette-see-all:visible"

  Scenario Outline: <keys> opens the palette
    When I visit "/admin"
    And I press the keys "<keys>"
    Then the admin markup holds "dialog#command-palette[open]"

    Examples:
      | keys      |
      | Meta+k    |
      | Control+k |
      | /         |

  Scenario: A slash typed into a field stays in the field, and the shortcut still opens the palette
    When I visit "/admin/tasks/new"
    And I type "half/day" in "main [name='task[title]']" and pick its letters 8 to 8
    Then the admin markup lacks "dialog#command-palette[open]"
    And "main [name='task[title]']" keeps focus, the text "half/day" and the letters 8 to 8 picked
    When I press the keys "Meta+/"
    Then the admin markup holds "dialog#command-palette[open]"

  Scenario: Typing a query keeps the rows that match and offers to see every result or write a task
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "mail" in the palette
    Then "#command-palette-mail" shows
    And the admin markup lacks "#command-palette-posts:visible"
    And the palette picks "command-palette-mail"
    And "[aria-labelledby='command-palette-group-inbox']" shows
    And the admin markup lacks "[aria-labelledby='command-palette-group-publish']:visible"
    And the admin markup holds "[data-palette-status]:has-text('1 result')"
    And "#command-palette-create-task-typed:has-text('Create task “mail”')" shows
    And "#command-palette-see-all:has-text('See all results for “mail”')" shows
    And the admin markup lacks "#command-palette-create-journal-entry:visible"

  Scenario: Typing a category name lists that category's screens
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "publish" in the palette
    Then "[aria-labelledby='command-palette-group-publish'] #command-palette-posts" shows
    And "[aria-labelledby='command-palette-group-publish'] #command-palette-social" shows
    And "[aria-labelledby='command-palette-group-publish'] #command-palette-files" shows

  Scenario: Running Create task with a query fills the title in the dialog
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "Buy stamps" in the palette
    And I click the palette row "command-palette-create-task-typed"
    Then the create task dialog's title holds "Buy stamps"

  Scenario: Running Keyboard shortcuts opens the key help
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "keyboard" in the palette
    And I press the keys "Enter"
    Then the key help is open

  Scenario: Running Toggle theme flips the theme each time
    When I visit "/admin"
    Then running Toggle theme from the palette flips the theme each time

  Scenario: The actions are found by name or by what they do
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "crea" in the palette
    Then "#command-palette-create-task:has-text('Create task')" shows
    When I open the palette again
    And I type "new task" in the palette
    Then the palette picks "command-palette-create-task"
    When I open the palette again
    And I type "decision" in the palette
    Then "[aria-labelledby='command-palette-group-actions'] #command-palette-create-decision:has-text('Create decision')" shows
    When I open the palette again
    And I type "create decision" in the palette
    Then the palette picks "command-palette-create-decision"
    When I open the palette again
    And I type "write in the journal" in the palette
    Then the palette picks "command-palette-create-journal-entry"
    When I open the palette again
    And I type "post" in the palette
    Then "[aria-labelledby='command-palette-group-actions'] #command-palette-new-post:has-text('New post')" shows
    And "[aria-labelledby='command-palette-group-actions'] #command-palette-new-social-post:has-text('New social post')" shows

  Scenario: Log work matches no action
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "log work" in the palette
    Then the admin markup holds "dialog#command-palette[open]"
    And the admin markup lacks "[aria-labelledby='command-palette-group-actions'] [data-palette-option]:visible"

  Scenario: A query that matches an action and a task lists the action above the task
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Create the invoice', 2, 'next');
      """
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "create" in the palette
    Then the palette lists "Create task" above "Create the invoice"

  Scenario: Searching the tasks finds the open task under Records with its kind and label
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "accountant" in the palette
    Then ".pal-g:text-matches('records', 'i')" shows
    And ".pal-r:has-text('Email the accountant')" shows
    And the palette row "Email the accountant" is labelled "task 1"

  Scenario: A section name a record also holds keeps the section picked once records load
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Check the activity feed', 2, 'next');
      """
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "activity" in the palette
    Then ".pal-r:has-text('Check the activity feed')" shows
    And the palette picks "command-palette-activity"

  Scenario: Searching the decisions finds the decision, labelled as one
    Given the database runs:
      """
      INSERT INTO decisions (title, problem) VALUES ('Pick a blimp hangar', 'Where the blimp sleeps');
      """
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "hangar" in the palette
    Then ".pal-r:has-text('Pick a blimp hangar') .pal-r-sub:has-text('decision')" shows

  Scenario: Searching a phrase from a journal entry lists it under Records and opens it on enter
    Given the database runs:
      """
      INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
        VALUES ('2026-10-01', '09:00', E'Walked the levee at dawn\nThe river ran high', '<p>Walked the levee at dawn</p>');
      """
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "levee" in the palette
    Then "[aria-labelledby='command-palette-group-records'] .pal-r-label:has-text('Walked the levee at dawn')" shows
    And "[aria-labelledby='command-palette-group-records'] .pal-g:text-matches('records', 'i')" shows
    And "[aria-labelledby='command-palette-group-records'] .pal-r-sub:has-text('journal')" shows
    And ".pal-r-match:has-text('levee')" shows
    When I press the keys "Enter"
    Then the admin address is "/admin/journal?to=2026-10-01"

  Scenario: The search waits until I type and asks once when I type fast
    When I open "/admin" and its live stream
    And I press the keys "Meta+/"
    Then "/admin/search/palette" was asked for 0 times
    When I type "accountant" in the palette
    Then ".pal-r:has-text('Email the accountant')" shows
    And "/admin/search/palette" was asked for 1 time

  Scenario: A reply that a newer one overtakes leaves the newer results
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Call the plumber', 2, 'next');
      """
    When I visit "/admin"
    And the next refetch of "/admin/search/palette" is held once the server answers
    And I press the keys "Meta+/"
    And I type "plumber" in the palette
    And the held refetch arrives
    And I press the keys "Backspace Backspace Backspace Backspace Backspace Backspace Backspace"
    And I type "accountant" in the palette
    Then ".pal-r:has-text('Email the accountant')" shows
    When the held refetch lands
    Then ".pal-r:has-text('Call the plumber')" does not show within a second
    And ".pal-r:has-text('Email the accountant')" shows

  Scenario: Opening it again clears the last results
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "accountant" in the palette
    Then ".pal-r:has-text('Email the accountant')" shows
    When I open the palette again
    Then the admin markup lacks ".pal-r:has-text('Email the accountant')"

  Scenario: See all results sits below the records and opens the search screen
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) SELECT 'Call the plumber ' || n, n + 1, 'next' FROM generate_series(0, 8) AS n;
      """
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "plumber" in the palette
    Then the palette shows 8 rows reading "Call the plumber"
    And the last two palette rows are "command-palette-see-all" and "command-palette-create-task-typed"
    When I click the palette row "command-palette-see-all"
    Then the admin address is "/admin/search?q=plumber"
    And the admin markup holds 9 of ".li-title:has-text('Call the plumber')"

  Scenario: See all results opens from the keyboard
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) SELECT 'Call the plumber ' || n, n + 1, 'next' FROM generate_series(0, 8) AS n;
      """
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "plumber" in the palette
    Then the palette shows 8 rows reading "Call the plumber"
    When I press the keys "End ArrowUp Enter"
    Then the admin address is "/admin/search?q=plumber"

  Scenario: Running a task row opens the task
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "accountant" in the palette
    Then ".pal-r:has-text('Email the accountant')" shows
    When I press the keys "Enter"
    Then the admin address is "/admin/tasks/1"

  Scenario: Hovering a row picks it out
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I hover the palette row "command-palette-mail" once the palette settles
    Then the palette picks "command-palette-mail"

  Scenario: The arrows step down and back up, and stop at the top
    When I visit "/admin"
    And I press the keys "Meta+/ ArrowDown"
    Then the palette picks "command-palette-create-decision"
    When I press the keys "ArrowUp"
    Then the palette picks "command-palette-create-task"
    When I press the keys "ArrowDown ArrowUp ArrowUp"
    Then the palette picks "command-palette-create-task"

  Scenario: Enter goes to the section
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "mail" in the palette
    And I press the keys "Enter"
    Then the admin address is "/admin/mail"

  Scenario: Running Create task opens the dialog where I am, and saving it captures the task
    When I visit "/admin/posts"
    And I press the keys "Meta+/"
    And I type "create task" in the palette
    And I press the keys "Enter"
    Then the admin markup lacks "dialog#command-palette[open]"
    And the admin markup holds "dialog#task-create[open]"
    And the admin address is "/admin/posts"
    When I save the create task dialog as "Call the plumber" on the "today" list
    Then ".toast:has-text('Task captured')" shows
    And ".task-title:has-text('Call the plumber')" shows

  Scenario: Running Create decision opens the new decision form
    When I visit "/admin/posts"
    And I press the keys "Meta+/"
    And I type "create decision" in the palette
    And I press the keys "Enter"
    Then the admin address is "/admin/decisions/new"

  Scenario: Running Create journal entry opens the journal modal where I am, ready to write
    When I visit "/admin/posts"
    And I press the keys "Meta+/"
    And I type "journal entry" in the palette
    And I press the keys "Enter"
    Then the admin markup holds "dialog#journal-write[open]"
    And the admin address is "/admin/posts"
    And "#journal-write-body:focus" shows

  Scenario: Running New post opens the new post form
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "new post" in the palette
    And I press the keys "Enter"
    Then the admin address is "/admin/posts/new"

  Scenario: Running New social post opens the composer, ready to write
    When I visit "/admin/posts"
    And I press the keys "Meta+/"
    And I type "new social post" in the palette
    And I press the keys "Enter"
    Then the admin address is "/admin/social?write=1"
    And "[data-social-part] [data-social-body]:focus" shows

  Scenario: Saved views wait for the palette to open and for me to type
    Given a saved view "Stale drafts" on the posts screen with the filters:
      """
      { "status": "draft" }
      """
    And a saved view "Next up" on the tasks screen with the filters:
      """
      { "filter": "next" }
      """
    When I open "/admin" and its live stream
    Then "/admin/saved-views/palette" was asked for 0 times
    When I press the keys "Meta+/"
    Then the admin markup holds "#command-palette-saved-view-1"
    And "/admin/saved-views/palette" was asked for 1 time
    And the admin markup lacks "[aria-labelledby='command-palette-group-saved-views']:visible"

  Scenario: Typing part of a view's name lists it with its screen and opens it with its filters
    Given a saved view "Stale drafts" on the posts screen with the filters:
      """
      { "status": "draft" }
      """
    And a saved view "Next up" on the tasks screen with the filters:
      """
      { "filter": "next" }
      """
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "stale" in the palette
    Then "[aria-labelledby='command-palette-group-saved-views'] .pal-g:text-matches('saved views', 'i')" shows
    And "[aria-labelledby='command-palette-group-saved-views'] .pal-r:has(.pal-r-label:text-is('Stale drafts')):has(.pal-r-sub:text-is('posts'))" shows
    And the admin markup lacks ".pal-r:has-text('Next up'):visible"
    When I press the keys "Enter"
    Then the admin address is "/admin/posts?status=draft"

  Scenario: A view deleted before a reload drops out of the palette
    Given a saved view "Stale drafts" on the posts screen with the filters:
      """
      { "status": "draft" }
      """
    And a saved view "Next up" on the tasks screen with the filters:
      """
      { "filter": "next" }
      """
    And the database runs:
      """
      DELETE FROM saved_views WHERE name = 'Stale drafts';
      """
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "next" in the palette
    Then ".pal-r:has-text('Next up')" shows
    When I press the keys "Backspace Backspace Backspace Backspace"
    And I type "stale" in the palette
    Then ".pal-r:has-text('Stale drafts')" does not show within a second

  Scenario: On a phone the saved views fit and open where I tap
    Given a saved view "Stale drafts" on the posts screen with the filters:
      """
      { "status": "draft" }
      """
    And the admin window is 375 by 800
    When I visit "/admin"
    And I tap the top bar search button
    And I type "stale" in the palette
    Then ".pal-r:has-text('Stale drafts')" shows
    And the page does not scroll sideways
    When I click the palette row reading "Stale drafts"
    Then the admin address is "/admin/posts?status=draft"

  Scenario: The palette with a saved view passes axe in light and dark
    Given a saved view "Stale drafts" on the posts screen with the filters:
      """
      { "status": "draft" }
      """
    When I visit "/admin"
    And I press the keys "Meta+/"
    And I type "stale" in the palette
    Then ".pal-r:has-text('Stale drafts')" shows
    And the page has no axe breaches in light or dark

  Scenario: Escape closes the palette
    When I visit "/admin"
    And I press the keys "Meta+/"
    Then the admin markup holds "dialog#command-palette[open]"
    When I press the keys "Escape"
    Then the admin markup lacks "dialog#command-palette[open]"

  Scenario: A click outside closes the palette, and the keyboard opens it again
    When I visit "/admin"
    And I press the keys "Meta+/"
    Then the admin markup holds "dialog#command-palette[open]"
    When I click the admin window at 5, 5
    Then the admin markup lacks "dialog#command-palette[open]"
    When I press the keys "Meta+/"
    Then the admin markup holds "dialog#command-palette[open]"

  Scenario: On a phone a 44px button opens the palette and the page stays put sideways
    Given the admin window is 375 by 800
    When I visit "/admin"
    Then "button.top-bar-search" shows
    And the page does not scroll sideways
    And the top bar search button measures at least 44px each way
    When I tap the top bar search button
    Then the admin markup holds "dialog#command-palette[open]"

  Scenario Outline: On a phone tapping <row> goes to <path>
    Given the admin window is 375 by 800
    When I visit "/admin"
    And I tap the top bar search button
    And I click the palette row "<row>"
    Then the admin address is "<path>"

    Examples:
      | row                             | path                  |
      | command-palette-mail            | /admin/mail           |
      | command-palette-new-post        | /admin/posts/new      |
      | command-palette-new-social-post | /admin/social?write=1 |

  Scenario Outline: <path> passes axe in light and dark
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path                    |
      | /admin                  |
      | /admin/posts            |
      | /admin/tasks/new        |
      | /admin/tasks/1          |
      | /admin/mail             |
      | /admin/search?q=plumber |
      | /admin/decisions/new    |
      | /admin/posts/new        |
      | /admin/social?write=1   |
      | /admin/journal          |
