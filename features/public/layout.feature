Feature: Public layouts
  The public pages set their columns side by side on a wide screen and stack them on a narrow one.

  Scenario: The about sidebar sticks beside the prose from 900px and follows it below
    Given the career history:
      | role     |
      | Engineer |
    And my window is 1280 by 800
    When I visit "/about"
    Then the "position" of "aside" is "sticky"
    And "aside" sits right of ".prose"
    Given my window is 800 by 800
    Then the "position" of "aside" is "static"
    And "aside" sits below ".prose"

  Scenario: The home sections sit side by side from 900px and stack below, the link on the kicker's row at the far edge
    Given the posts:
      | title | summary              |
      | Hello | One line and no more |
    And the projects:
      | name | tagline         |
      | sai  | Terminal colors |
    And my window is 1280 by 800
    When I visit "/"
    Then ".sh .sec-l" sits on the row of ".sh .kicker"
    And the right edge of ".sh .sec-l" meets the right edge of ".sh"
    And "main" runs the full width of the window
    And ".g > section:last-child" sits right of ".g > section:first-child"
    And ".g > section:last-child" is at least 300 pixels wide
    Given my window is 800 by 800
    Then ".g > section:last-child" sits below ".g > section:first-child"

  Scenario: An edit note's date sits beside the note on a wide screen and above it on a phone
    Given the posts:
      | title |
      | Hello |
    And the post "Hello" carries the edit notes:
      | note              | at                   |
      | fixed the numbers | 2026-09-07T12:00:00Z |
    And my window is 1200 by 800
    When I visit "/writing/hello"
    Then ".post-edit-note" sits right of ".post-edit-date"
    Given my window is 400 by 800
    Then ".post-edit-note" sits at or below ".post-edit-date"

  Scenario: A post's title grows with the viewport
    Given the posts:
      | title | body    |
      | Hello | one two |
    And my window is 800 by 800
    When I visit "/writing/hello"
    And I note the font size of "h1.p-name"
    Given my window is 1600 by 800
    Then the font size of "h1.p-name" is larger than I noted

  Scenario: The table of contents marks the heading in view, stays in view, and hides below 1100px
    Given a long post "Long" with the sections "One, Two, Three, Four"
    And my window is 1280 by 800
    When I visit "/writing/long"
    Then ".toc a[aria-current='location']" reads "One"
    When I scroll "#three" into view
    Then ".toc a[aria-current='location']" reads "Three"
    And ".toc a[aria-current]" counts 1
    And the top of ".toc" sits 92 pixels down the window, give or take one
    Given my window is 1000 by 800
    Then ".toc" is hidden

  Scenario: The writing list sets the meta beside the title at 720px, stacks it narrower, and links only the title
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('ruby', 'mk-violet', 'public')
      """
    And the posts:
      | title | tags | published            | summary              | body        |
      | Hello | ruby | 2026-09-07T12:00:00Z | One line and no more | <440 words> |
    When I visit "/writing"
    Then the texts of ".entry-meta > *" are:
      | Sep 7, 2026 |
      | ruby        |
      | 2 min       |
    And the middle of ".entry-blurb" sits inside no link
    When I set the width of ".entries" to 720 pixels
    Then ".entry-title" sits right of ".entry-meta"
    When I set the width of ".entries" to 719 pixels
    Then ".entry-title" sits at or below ".entry-meta"
