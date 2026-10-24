Feature: Note folders
  A folder page lists what a folder holds, and its settings rename, move, describe and remove it.

  Background:
    Given I am signed in to the admin
    And the note folder "work/clients" described as "Paid work, one per client"

  Scenario: The folder page shows what the folder holds
    Given the note folder "work/clients/globex"
    And the notes:
      | title | body                                                         | folder       | pinned | tags | edited |
      | Acme  | ```ruby\n\n## The [[Brief\|first call]] went _well_\nmore [[Acme]] | work/clients | yes    | ruby | 1      |
      | Brief | One two three                                                | work/clients |        |      | 60     |
    When I open the note folder "work/clients"
    Then the folder page heads with "clients", "Paid work, one per client" and "2 notes · 1 folder"
    And the folder page shows the path back to "work"
    And the tree marks the note folder "clients" open
    And the folder page gathers the tag "#ruby"
    And the folder page lists "globex, Acme, Brief"
    And the folder page shows "globex" as empty
    And the folder page shows "Acme" pinned with the excerpt "The first call went well"
    And the folder page shows "Brief" with "3 words" and "1 backlink"
    And the folder page shows "Acme" with no backlinks
    And the folder page makes notes and subfolders in "work/clients"
    And removing the folder asks "Remove clients? Its 2 notes move to work. Folder links are dropped."
    And the page has no axe breaches in light or dark

  Scenario: The folder page reads on a phone
    Given I use a phone
    When I open the note folder "work/clients"
    Then the notes tree is hidden
    And the page has no axe breaches in light or dark
    When I click "Files"
    Then the notes tree shows

  Scenario: An empty folder says so
    When I open the note folder "work/clients"
    Then I see "This folder is empty"

  Scenario: A folder that does not exist is missing
    When I visit "/admin/notes/folders/999999"
    Then the server answers 404

  Scenario: The folder menu offers what the design draws
    Given the note folder "work/inner"
    And the notes:
      | title | folder |
      | Plan  | work   |
    And a task "Write the brief"
    And the note_folder "work" links the task "Write the brief"
    When I open the notes
    And I right-click the note folder "work" in the tree
    Then the menu offers "Open folder, Collapse, New note here, New subfolder, Rename, Move to, Linked records, Copy path, Remove folder"
    And the menu leaves out "work/inner"
    And the menu counts 1 beside "Linked records"
    And removing the folder from the menu warns "Click again · 1 note moves up"
    When I choose "Linked records" in the menu
    Then I am on the note folder "work"

  Scenario: The menu of a folded folder offers to unfold it
    When I visit "/admin/notes/folders/1/menu?shut=1"
    Then I see "Expand"

  Scenario: I rename a folder from its menu
    When I open the notes
    And I right-click the note folder "work" in the tree
    And I choose "Rename" in the menu
    And I type "jobs" in the menu field "work"
    Then the tree holds the note folder "jobs"
    And there is no note folder "work"

  Scenario: I make a subfolder from a folder's menu
    When I open the notes
    And I right-click the note folder "work" in the tree
    And I choose "New subfolder" in the menu
    And I type "drafts" in the menu field "Folder name…"
    Then the note folder "drafts" sits in "work"

  Scenario: I remove a folder from its menu and its notes move up
    Given the notes:
      | title | folder       |
      | Acme  | work/clients |
    When I open the notes
    And I right-click the note folder "clients" in the tree
    And I choose "Remove folder" in the menu
    And I choose "Click again" in the menu
    Then the toast says "Folder removed"
    And the note "Acme" sits in "work"
    And there is no note folder "clients"

  Scenario: The settings rename the folder and stay on its page
    When I open the note folder "work/clients"
    And I rename the open folder to "accounts"
    Then the toast says "Renamed"
    And I am on the note folder "work/accounts"

  Scenario: The settings move the folder inside another
    Given the note folder "archive"
    And the note folder "work/clients/globex"
    When I open the note folder "work/clients"
    Then the folder settings offer to move into "archive, work"
    When I move the open folder to "Archive"
    Then the toast says "Moved to archive"
    And the note folder "clients" sits in "archive"

  Scenario: A folder cannot move inside itself
    When I open the note folder "work"
    And I move the open folder to "work/clients"
    Then the toast says "A folder can't move inside itself"
    And the note folder "work" sits in ""

  Scenario: The settings edit the description but refuse one past the limit
    When I open the note folder "work/clients"
    And I describe the open folder as "Old clients too"
    Then the toast says "Description saved"
    And I see "Old clients too"
    When I describe the open folder with 1001 letters
    Then the toast says "Nothing changed · check what you typed"

  Scenario: Removing a folder from its page moves its notes up and opens the parent
    Given the notes:
      | title | folder       |
      | Acme  | work/clients |
    And a task "Write the brief"
    And the note "Acme" links the task "Write the brief"
    And the note_folder "work/clients" links the task "Write the brief"
    When I open the note folder "work/clients"
    And I click "Remove folder"
    And I click "Remove folder"
    Then I am on the note folder "work"
    And the note "Acme" sits in "work"
    And 1 record link remains

  Scenario: Removing a top level folder opens the notes home
    When I open the note folder "work"
    And I click "Remove folder"
    And I click "Remove folder"
    Then I am on "/admin/notes"
    And the note folder "clients" sits in ""
