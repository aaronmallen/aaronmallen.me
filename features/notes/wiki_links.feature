Feature: Wiki links between notes
  A note links another with [[Title]], and the notes keep track of what links where.

  Background:
    Given I am signed in to the admin
    And the notes:
      | title | body                                 | folder |
      | Ruby  | See [[Rails\|the framework]]          |        |
      | Rails | Built on [[ruby]]\n\n- [[Rack]]       | work   |

  Scenario: A wiki link opens the note it names and keeps its text
    When I open the note "Ruby"
    Then the wiki link "the framework" opens the note "Rails"

  Scenario: A note lists its backlinks and the links not written yet
    When I open the note "Rails"
    Then the note lists the backlink "Ruby" with "See the framework"
    And the note links out to "Racknot written, Ruby"
    And the wiki link "Rack" is a button that makes it in "work"
    And deleting the note asks "Delete “Rails”? 1 note links to it."

  Scenario: A link to a note not written yet makes it in the same folder
    When I open the note "Rails"
    And I click the missing wiki link "Rack"
    Then I am editing the note "Rack"
    And the note "Rack" sits in "work"

  Scenario: The notes home lists titles linked but not written
    When I open the notes
    Then the notes home lists "Rack" linked but not written from "Rails"
    And the notes home counts "1 backlink" for "Rails"

  Scenario: Renaming a note rewrites the links to it
    When I open the note "Rails"
    And I right-click the note "Rails" in the tree
    And I choose "Rename" in the menu
    And I type "Hanami" in the menu field "Rails"
    Then the toast says "Renamed · links updated in 1 note"
    And the note "Ruby" reads "See [[Hanami|the framework]]"

  Scenario: Renaming a linked note in the editor says how many notes changed
    When I edit the note "Rails"
    And I type "Hanami" as the note title
    And I leave the note title
    Then the toast says "Renamed · links updated in 1 note"
    And the note "Ruby" reads "See [[Hanami|the framework]]"
