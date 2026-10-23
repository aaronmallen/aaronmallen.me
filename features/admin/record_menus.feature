Feature: Admin journal, decision, file, link and tag row menus
  Each row on these pages carries a menu of what it can do, and each action lands back where the menu opened.

  Background:
    Given I am signed in to the admin

  Scenario Outline: A menu for a <kind> row that is gone answers 404
    Then visiting "/admin/<kind>/0/menu" answers 404

    Examples:
      | kind      |
      | journal   |
      | decisions |
      | files     |
      | links     |
      | tags      |

  Scenario: A journal entry's menu heads with its date and time and holds every action an entry takes
    Given the record menus have the journal entry "shipped it" tagged home
    When I visit "/admin/journal/1/menu?return_to=%2Fadmin%2Fjournal%3Fq%3Dship"
    Then the record page's "[data-context-menu] > .ctx-head" reads "Oct 1 · 09:30"
    And the record menu items read "Edit, Linked records, Tags, #home, #work, Copy text, Delete entry"
    And the record page has "a.ctx-item[href='/admin/journal?to=2026-10-01&edit=1']" reading "Edit"
    And the record page has "a.ctx-item[href='/admin/journal?to=2026-10-01&edit=1#journal-links-1']" reading "Linked records"
    And every record menu form returns to "/admin/journal?q=ship"

  Scenario: A journal entry's menu unticks a tag it has, ticks one it lacks and lists only private tags
    Given the record menus have the journal entry "shipped it" tagged home
    When I visit "/admin/journal/1/menu?return_to=%2Fadmin%2Fjournal%3Fq%3Dship"
    Then the record page has "[role=menuitemcheckbox][aria-checked=true]" reading "#home"
    And the record page has "form[action='/admin/journal/1/tags/delete'] input[type=hidden][name=tag][value=home]"
    And the record page has "form[action='/admin/journal/1/tags'] input[type=hidden][name=tag][value=work]"
    And the record page has no "[role=menuitemcheckbox]:has-text('#ruby')"

  Scenario: A journal entry's menu copies the text and asks before it deletes
    Given the record menus have the journal entry "shipped it" tagged home
    When I visit "/admin/journal/1/menu?return_to=%2Fadmin%2Fjournal%3Fq%3Dship"
    Then the record menu copies "Copy text" as "shipped it"
    And the record page's "form[action='/admin/journal/1/delete'] button" has the data-confirm-inline "Click again · can't undo"

  Scenario: Deleting a journal entry from its menu lands back on the page it opened on
    Given the record menus have the journal entry "shipped it" tagged home
    When I post the record link form to "/admin/journal/1/delete" with "return_to=/admin/journal?q=ship"
    Then the record link post lands on "/admin/journal?q=ship"
    And the record page has "[data-toast] .toast" reading "Entry deleted"

  Scenario: An open decision's menu heads with its number and title and holds every action it takes
    Given a record link decision titled "Pick a queue"
    And the record menus have the private tag "infra" coloured "mk-blue"
    When I visit "/admin/decisions/1/menu?return_to=%2Fadmin%2Fdecisions%3Fstatus%3Dopen"
    Then the record page has ".ctx-head" reading "#1 · Pick a queue"
    And the record menu items read "Open, Edit, Copy number, Tags, #infra, Drop…"
    And the record menu copies "Copy number" as "#1"
    And the record page has "form[action='/admin/decisions/1/tags'] input[name=tag][value=infra]"

  Scenario: An open decision's menu opens the drop reason form in a dialog that posts back to the page
    Given a record link decision titled "Pick a queue"
    When I visit "/admin/decisions/1/menu?return_to=%2Fadmin%2Fdecisions%3Fstatus%3Dopen"
    Then the record page has "a[data-dialog-open='decision-1-drop']" reading "Drop…"
    And the record page's "a[data-dialog-open='decision-1-drop']" has the aria-haspopup "dialog"
    And the record page's "dialog#decision-1-drop form#decision-drop-form[data-morph]" has the action "/admin/decisions/1/drop"
    And the record page's "dialog#decision-1-drop form#decision-drop-form input[name=return_to]" holds "/admin/decisions?status=open"

  Scenario: A dropped decision's menu offers reopen in place of drop
    Given the database runs:
      """
      insert into decisions (title, problem, status) values ('Pick a queue', 'It came up', 'dropped')
      """
    When I visit "/admin/decisions/1/menu"
    Then the record page has ".ctx-label" reading "Reopen…"
    And the record page has no ".ctx-label:has-text('Drop…')"
    And the record page's "form[action='/admin/decisions/1/reopen']" has the id "decision-reopen-form"

  Scenario: Dropping a decision from the menu lands back on the page it opened on
    Given a record link decision titled "Pick a queue"
    When I post the record link form to "/admin/decisions/1/drop" with "decision[reason]=moot&return_to=/admin/decisions"
    Then the record link post lands on "/admin/decisions"
    And the record page has "[data-toast] .toast" reading "Dropped"

  Scenario: Dropping a decision with a blank reason answers the form and its error
    Given a record link decision titled "Pick a queue"
    When I post the record link form to "/admin/decisions/1/drop" with "decision[reason]=&return_to=/admin/decisions"
    Then the record link post answers 422
    And the record page's "form[action='/admin/decisions/1/drop']" has the id "decision-drop-form"
    And the record page has "form[action='/admin/decisions/1/drop']" reading "Say why."

  Scenario: A file's menu holds every action a file takes, opens its details and the file and copies its link
    Given the record menus have the file "deck.pdf" of the type "application/pdf" at "deck"
    When I visit "/admin/files/1/menu?return_to=%2Fadmin%2Ffiles%3Fkind%3Dother"
    Then the record menu items read "Details, Open file, Copy link, Copy as markdown, Delete file"
    And every record menu form returns to "/admin/files?kind=other"
    And the record page has "a[data-dialog-open='share-1-drawer']" reading "Details"
    And the record page has "a.ctx-item[href='http://shares.localhost/deck'][target=_blank]" reading "Open file"
    And the record menu copies "Copy link" as "http://shares.localhost/deck"
    And the record menu copies "Copy as markdown" as "[deck.pdf](http://shares.localhost/deck)"

  Scenario: A file's menu copies an image as an image
    Given the record menus have the file "shot.png" of the type "image/png" at "shot"
    When I visit "/admin/files/1/menu"
    Then the record menu copies "Copy as markdown" as "![](http://shares.localhost/shot)"

  Scenario: Deleting a file from its menu lands back on the page it opened on
    Given the record menus have the file "deck.pdf" of the type "application/pdf" at "deck"
    When I post the record link form to "/admin/files/1/delete" with "return_to=/admin/files?kind=other"
    Then the record link post lands on "/admin/files?kind=other"

  Scenario: A link's menu holds every action a link takes and copies the short link, the destination and markdown
    Given the record menus have the short link "talk-now" to "https://example.com/talk"
    When I visit "/admin/links/1/menu?return_to=%2Fadmin%2Flinks%3Fsort%3Dclicks"
    Then the record menu items read "Edit, Open destination, Copy short link, Copy destination, Copy as markdown, Delete link"
    And the record page has "a[data-dialog-open='link-1-drawer']" reading "Edit"
    And the record menu copies "Copy short link" as "http://shares.localhost/talk-now"
    And the record menu copies "Copy destination" as "https://example.com/talk"
    And the record menu copies "Copy as markdown" as "[example.com](http://shares.localhost/talk-now)"

  Scenario: Deleting a link from its menu lands back on the page it opened on
    Given the record menus have the short link "talk-now" to "https://example.com/talk"
    When I post the record link form to "/admin/links/1/delete" with "return_to=/admin/links?sort=clicks"
    Then the record link post lands on "/admin/links?sort=clicks"

  Scenario: A tag's menu holds every action a tag takes and ticks its colour
    Given the record menus have the private tag "home" coloured "mk-blue"
    When I visit "/admin/tags/1/menu?scope=private&return_to=%2Fadmin%2Fsettings%2Ftagging%3Fscope%3Dprivate"
    Then the record menu items read "Rename…, Colour, Pink, Green, Blue, Violet, Sand, Orange, Copy, Delete tag"
    And the record menu copies "Copy" as "#home"
    And the record page has "[role=menuitemcheckbox][aria-checked=true]" reading "Blue"

  Scenario: A tag's menu answers 404 for a tag in the other scope
    Given the record menus have the private tag "home" coloured "mk-blue"
    Then visiting "/admin/tags/1/menu?scope=public" answers 404

  Scenario: Recolouring a tag from its menu lands back on its section of the page it opened on
    Given the record menus have the private tag "home" coloured "mk-blue"
    When I post the record link form to "/admin/tags/1" with "scope=private&tag[name]=home&tag[color]=mk-pink&return_to=/admin/settings/tagging?scope=private%26q=ho"
    Then the record link post lands on "/admin/settings/tagging?scope=private&q=ho#tags"
    And the record page has "[data-toast] .toast" reading "Tag recoloured"

  Scenario: Deleting a tag from its menu lands back on its section of the page it opened on
    Given the record menus have the private tag "home" coloured "mk-blue"
    When I post the record link form to "/admin/tags/1/delete" with "scope=private&return_to=/admin/settings/tagging?scope=private%26q=ho"
    Then the record link post lands on "/admin/settings/tagging?scope=private&q=ho#tags"

  Scenario: Deleting a tag from elsewhere lands back where it opened
    Given the record menus have the private tag "home" coloured "mk-blue"
    When I post the record link form to "/admin/tags/1/delete" with "scope=private&return_to=/admin/tasks?filter=next"
    Then the record link post lands on "/admin/tasks?filter=next"

  Scenario: Rows carry their menus on the journal, decisions, files, links and tags
    Given the record menus have the journal entry "shipped it" tagged home
    And a record link decision titled "Pick a queue"
    And the record menus have the file "deck.pdf" of the type "application/pdf" at "deck"
    And the record menus have the short link "talk-now" to "https://example.com/talk"
    When I visit "/admin/journal?to=2026-10-01"
    Then the record page has ".journal-entry[data-menu='/admin/journal/1/menu']"
    When I visit "/admin/decisions"
    Then the record page has ".decision-row[data-menu='/admin/decisions/1/menu']"
    When I visit "/admin/files"
    Then the record page has ".file-card[data-menu='/admin/files/1/menu']"
    When I visit "/admin/links"
    Then the record page has ".link-row[data-menu='/admin/links/1/menu']"
    When I visit "/admin/settings/tagging?scope=private"
    Then the record page has ".tag-row[data-menu='/admin/tags/1/menu?scope=private']"

  Scenario Outline: The pages that carry these menus have no axe breaches
    Given the record menus have the journal entry "shipped it" tagged home
    And a record link decision titled "Pick a queue"
    And the record menus have the file "deck.pdf" of the type "application/pdf" at "deck"
    And the record menus have the short link "talk-now" to "https://example.com/talk"
    When I visit "<page>"
    Then the page has no axe breaches in light or dark

    Examples:
      | page                                 |
      | /admin/journal?to=2026-10-01         |
      | /admin/decisions                     |
      | /admin/files                         |
      | /admin/links                         |
      | /admin/settings/tagging?scope=private |
