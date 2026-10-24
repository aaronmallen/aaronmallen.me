Feature: A note
  A note page renders the note as Markdown beside its facts, and its editor saves as I type.

  Background:
    Given I am signed in to the admin

  Scenario: The note page shows the note and its facts
    Given the notes:
      | title | body        | folder | tags |
      | Plan  | Ship **it** | work   | ruby |
    When I open the note "Plan"
    Then the note body shows "it" in bold
    And the note page shows the path "work /Plan"
    And the note shows the tag "#ruby"
    And the note facts say "created \w+ \d+.*2 words.*private"
    And deleting the note asks "Delete “Plan”?"
    And the page has no axe breaches in light or dark

  Scenario: A note that does not exist is missing
    When I visit "/admin/notes/999999"
    Then the server answers 404

  Scenario: On a phone the note hides the tree and goes back to it
    Given the note "Plan"
    And I use a phone
    When I open the note "Plan"
    Then the note page heads with "Plan"
    And the notes tree is hidden
    And the page has no axe breaches in light or dark
    When I click "Files"
    Then the notes tree shows

  Scenario: The editor saves the body as I type
    Given the notes:
      | title | body         |
      | Plan  | Old [[Gone]] |
    When I edit the note "Plan"
    Then the note editor holds the version 1
    And the page has no axe breaches in light or dark
    When I type "First" in the note body
    Then the note status says it saved
    And the note "Plan" reads "First"
    When I type "See [[Rack]]" in the note body
    Then the note "Plan" reads "See [[Rack]]"
    And the note editor shows no refusal
    When I open the note "Plan"
    Then the note links out to "Racknot written"

  Scenario: The editor says when the note changed elsewhere
    Given the notes:
      | title | body |
      | Plan  | Old  |
    When I edit the note "Plan"
    And the note "Plan" changes elsewhere
    And I type "Mine" in the note body
    Then the note editor says "This note changed elsewhere"
    And the note "Plan" reads "Agent"

  Scenario: The editor keeps the old title when another note holds the new one
    Given the note "Plan"
    And the note "Taken"
    When I edit the note "Plan"
    And I type "taken" as the note title
    Then the note editor says "Another note is called “taken”"
    When I leave the note title
    Then the note title field holds "Plan"
    And there is a note "Plan"

  Scenario: The editor saves a tag I add
    Given the note "Plan"
    When I edit the note "Plan"
    And I add the tag "ruby" to the open note
    Then the note "Plan" carries the tags "ruby"

  Scenario: Without scripts the editor saves and comes back to the editor
    Given the note "Plan"
    And the note "Taken"
    And the admin scripts do not load
    When I edit the note "Plan"
    And I type "New body" in the note body
    And I click "Save"
    Then I am editing the note "Plan"
    And the note "Plan" reads "New body"
    When I type "Taken" as the note title
    And I click "Save"
    Then I see "Another note is called “Taken”"
    And there is a note "Plan"

  Scenario: I pin a note from its page
    Given the note "Plan"
    And the note "Other"
    When I open the note "Plan"
    And I click "Pin"
    Then the note tree lists the pinned note "Plan" first

  Scenario: I rename a note from its menu, but not to a title another note holds
    Given the note "Plan"
    And the note "Taken"
    When I open the note "Plan"
    And I right-click the note "Plan" in the tree
    And I choose "Rename" in the menu
    And I type "Taken" in the menu field "Plan"
    Then the toast says "Another note has that title"
    And there is a note "Plan"

  Scenario: I move a note to a new folder path and back to the top level
    Given the note "Plan"
    When I open the note "Plan"
    And I right-click the note "Plan" in the tree
    And I choose "Move to" in the menu
    And I type "work/clients" in the menu field "New folder…"
    Then the toast says "Moved to work/clients"
    And the note "Plan" sits in "work/clients"
    When I right-click the note "Plan" in the tree
    And I choose "Move to" in the menu
    And I choose "Top level" in the menu
    Then the note "Plan" sits in ""

  Scenario: I tag a note from its menu
    Given the note "Plan"
    When I open the note "Plan"
    And I right-click the note "Plan" in the tree
    And I choose "Tags" in the menu
    And I type "ruby" in the menu field "New tag…"
    Then the note "Plan" carries the tags "ruby"

  Scenario: I duplicate a note and the copy opens
    Given the notes:
      | title | body          | folder |
      | Plan  | See [[Brief]] | work   |
      | Brief |               |        |
    When I open the note "Plan"
    And I right-click the note "Plan" in the tree
    And I choose "Duplicate" in the menu
    Then I am on the note "Plan copy"
    And the note "Plan copy" reads "See [[Brief]]"
    And the note "Plan copy" sits in "work"
    When I open the note "Brief"
    Then the note lists the backlink "Plan copy" with "See Brief"

  Scenario: I delete a note from its page
    Given the note "Plan"
    And a task "Write the brief"
    And the note "Plan" links the task "Write the brief"
    When I open the note "Plan"
    And I click "Delete note"
    Then I see "Delete “Plan”?"
    When I click "Delete note"
    Then I am on "/admin/notes"
    And there is no note "Plan"
    And 0 record links remain

  Scenario: The note menu offers what the design draws
    Given the notes:
      | title | folder |
      | Plan  | work   |
    When I open the note "Plan"
    And I right-click the note "Plan" in the tree
    Then the menu offers "Open, Edit, Pin, Rename, Move to, Top level, work, Tags, Copy link, Duplicate, New note beside it, Delete note"
    And the menu copies "[[Plan]]"
