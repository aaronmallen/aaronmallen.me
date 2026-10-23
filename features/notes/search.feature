Feature: Searching notes
  The search box above the tree finds notes by title, body, folder and tag.

  Background:
    Given I am signed in to the admin
    And the notes:
      | title     | body                                           | folder  | tags | edited |
      | Glaze log | Tried celadon                                  | pottery |      | 1      |
      | Firing    | Intro\n## The **glaze** went [[Glaze log\|cloudy]] |         |      | 0      |
      | Wheel     | Centering                                      | pottery |      | 2      |
      | Errands   | Buy milk                                       |         | kiln | 3      |

  Scenario: Title matches come first, then the rest newest first
    When I open the notes
    Then the note search box asks for "search notes · #tag"
    When I search the notes for "glaze"
    Then the note search finds "Glaze log, Firing"
    And the note search hit "Glaze log" sits in "pottery"
    And the note search hit "Firing" sits in "/ · The glaze went cloudy"
    And the note search counts "2 matches"
    And the note search hit "Firing" keeps the search
    And the page has no axe breaches in light or dark

  Scenario: A search matches a note by its folder or its tags
    When I open the notes
    And I search the notes for "pottery"
    Then the note search finds "Glaze log, Wheel"
    When I search the notes for "kiln"
    Then the note search finds "Errands"
    And the note search hit "Errands" sits in "/"

  Scenario: A #tag search lists the notes that carry it
    When I open the notes
    And I search the notes for "#kiln"
    Then the note search finds "Errands"
    And the note search counts "1 tagged #kiln"
    When I search the notes for "#nothing"
    Then the note search offers nothing to create

  Scenario: A search with no match offers to create a note by that name
    When I open the notes
    And I search the notes for "Bisque"
    Then the note search counts "0 matches"
    And the note search offers to create "Bisque"

  Scenario: A search from a note keeps the note open and offers its folder
    When I open the note "Wheel"
    And I search the notes for "glaze"
    Then the note search finds "Glaze log, Firing"
    And the note search stays on the note "Wheel"
    When I search the notes for "Bisque"
    Then the note search offers to create it in "pottery"
