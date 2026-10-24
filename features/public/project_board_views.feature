Feature: Project board views
  The board shows as columns or as a list. A switch flips them without a reload and remembers the choice; with
  nothing saved the width picks, and the list fits a phone.

  Background:
    Given the projects:
      | name | board     |
      | sai  | published |
    And the tasks of the project "sai":
      | title                                                | status   | closed       | tags  |
      | A long title for a task that wraps on a narrow screen |          |              | audio |
      | Gone                                                 | canceled | 1 minute ago |       |
    And I clear the browser's saved choices

  Scenario: The switch shows the list without a reload, presses its button and writes the param
    Given my window is 1200 by 900
    When I visit "/projects/sai"
    And I mark the page
    And I click the button "list"
    Then only ".board-list" of ".board, .board-list" shows
    And the page does not reload
    And ".board-switch button[aria-pressed='true']" reads "list"
    And the page's query is "view=list"

  Scenario Outline: The param asks for the <view> at <width>px
    Given my window is <width> by 900
    When I visit "/projects/sai?view=<view>"
    Then only "<shown>" of ".board, .board-list" shows

    Examples:
      | width | view  | shown       |
      | 1200  | list  | .board-list |
      | 390   | board | .board      |

  Scenario: The last choice stays when no param asks
    Given my window is 1200 by 900
    When I visit "/projects/sai"
    And I click the button "list"
    And I visit "/projects/sai"
    Then only ".board-list" of ".board, .board-list" shows

  Scenario Outline: With nothing saved, <width>px shows <shown>, with script or without
    Given my window is <width> by 900
    When I visit "/projects/sai"
    Then only "<shown>" of ".board, .board-list" shows
    When I drop the board's view mark
    Then only "<shown>" of ".board, .board-list" shows
    And the page has no ".board-switch:visible"

    Examples:
      | width | shown       |
      | 390   | .board-list |
      | 700   | .board-list |
      | 701   | .board      |
      | 1200  | .board      |

  Scenario: A group closes from its header, and canceled starts closed and opens from its header
    Given my window is 390 by 844
    When I visit "/projects/sai"
    And I click the element ".board-group.backlog > summary"
    Then ".board-group.backlog .board-row" is hidden
    And ".board-group.canceled .board-row" is hidden
    When I click the element ".board-group.canceled > summary"
    Then ".board-group.canceled .board-row" is visible

  Scenario: A card's tag adds itself to the filter, and the field suggests project tags after label:
    Given my window is 1200 by 900
    When I visit "/projects/sai?view=board"
    And I click the element ".board .board-tags a.tag"
    Then "input[name='q']" has the value "label:audio"
    And the texts of ".board .board-title" are:
      | A long title for a task that wraps on a narrow screen |
    When I visit "/projects/sai?view=board"
    And I type "label:" into "input[name='q']"
    Then ".task-filter-list [role='option']" includes "#audio"

  Scenario: The list fits a phone with 44px tap targets
    Given my window is 390 by 844
    When I visit "/projects/sai"
    Then every one of ".board-switch button, .board-group > summary, .board-row" is at least 44 pixels tall
    And the page does not scroll sideways
    And the page has no axe breaches in light or dark
