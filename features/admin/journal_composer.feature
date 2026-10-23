Feature: Admin journal composer
  The composer counts words as you type, enables Save entry once there is text, titles its card with the chosen
  day and stays on screen while the entries scroll past. On a phone it stacks above the entries.

  Background:
    Given I am signed in to the admin

  Scenario Outline: The word count reads <count> for <text>
    When I visit "/admin/journal"
    And I write "<text>" in the journal field "Entry"
    Then the journal page shows "[data-journal-words]" reading "<count>"

    Examples:
      | text                      | count   |
      | one two three             | 3 words |
      | ## one --- two\n\tthree   | 5 words |
      | one                       | 1 word  |

  Scenario: Save entry starts disabled, enables once there is text and disables again when it is cleared
    When I visit "/admin/journal"
    Then the journal button "Save entry" is disabled
    When I write "walked" in the journal field "Entry"
    Then the journal button "Save entry" is enabled
    When I write "ab" in the journal field "Entry"
    And I press "Backspace"
    And I press "Backspace"
    Then the journal button "Save entry" is disabled

  Scenario: Save entry stays disabled for only whitespace
    When I visit "/admin/journal"
    And I write "  \n\t " in the journal field "Entry"
    Then the journal button "Save entry" is disabled

  Scenario: A toolbar snippet lands in the entry and counts its words
    When I visit "/admin/journal"
    And I click the journal composer's "Bold" tool
    Then the journal field "Entry" holds "**bold**"
    And the journal page shows "[data-journal-words]" reading "1 word"
    And the journal button "Save entry" is enabled

  Scenario: The preview renders the markup the saved entry shows, in the saved entry's typeface
    When I visit "/admin/journal"
    And I write "a **bold** day\n\n- one" in the journal field "Entry"
    And I switch the journal composer to "Preview"
    And I note the journal composer's preview
    And I switch the journal composer to "Write"
    And I click the button "Save entry"
    Then the journal toast reads "Journal entry saved · private"
    And the saved journal entry shows the noted preview's markup
    And the saved journal entry is set in the noted preview's typeface

  Scenario: The card takes the title of a chosen date, and Today again for today
    When I visit "/admin/journal"
    And I pick "2026-09-03" as the journal entry date
    Then the journal page shows "#journal-entry .card-title" reading "Thursday, September 3, 2026"
    When I pick "{today}" as the journal entry date
    Then the journal page shows "#journal-entry .card-title" reading "Today"

  Scenario: A backdated entry lands under the chosen date
    When I visit "/admin/journal"
    And I pick "{today-2}" as the journal entry date
    And I write "remembered" in the journal field "Entry"
    And I click the button "Save entry"
    Then the journal toast reads "Journal entry saved · private"
    And the journal entries on "{today-2}" read "remembered"

  Scenario: The composer stays in view below the top bar and a day heading sticks under it
    Given the journal holds numbered entries:
      | days back | count |
      | 0         | 3     |
      | 1         | 3     |
      | 2         | 3     |
      | 3         | 3     |
      | 4         | 3     |
      | 5         | 3     |
      | 6         | 3     |
      | 7         | 3     |
      | 8         | 3     |
      | 9         | 3     |
      | 10        | 3     |
      | 11        | 3     |
    When I visit "/admin/journal"
    And I scroll the journal to 1500
    Then the journal window is scrolled to 1500
    And ".journal-compose" sits at or below ".top-bar" on the journal page
    And ".journal-compose" starts within 200 pixels of the top of the journal window
    When I scroll into the fourth journal day
    Then a journal day heading sits right below the top bar

  Scenario: On a phone the composer stacks above the entries with its tags across the foot, above the date
    Given I use a phone
    When I visit "/admin/journal"
    Then ".journal-days" sits at or below ".journal-compose" on the journal page
    And the journal tags span the width of ".jbox-foot"
    And "#journal-entry-date" sits at or below ".jbox-foot .tag-pick" on the journal page

  Scenario: On a phone the quick-write modal puts its tags across the foot, above the Save button
    Given I use a phone
    When I visit "/admin/analytics"
    And I press the keys "w"
    Then "dialog#journal-write[open]" shows
    And the journal tags span the width of "#journal-write .journal-modal-foot"
    And "#journal-write .journal-modal-foot > .bt" sits at or below "#journal-write .tag-pick" on the journal page
