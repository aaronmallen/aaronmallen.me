Feature: Post edits
  A post's edit notes show under the heading Edits, grouped by the site's day, newest day first and oldest note
  first within a day, above the feedback line.

  Background:
    Given the posts:
      | title |
      | Hello |

  Scenario: The notes sit under Edits with each one's date and note, above the feedback line
    Given the post "Hello" carries the edit notes:
      | note              | at                   |
      | fixed the numbers | 2026-09-07T12:00:00Z |
    When I visit "/writing/hello"
    Then ".post-edits > h2.kicker" reads "Edits"
    And the texts of ".post-edit" are:
      | Sep 7, 2026 fixed the numbers |
    And the classes of "article .post-extras > *" are:
      | post-edits    |
      | post-feedback |
    And the page has no axe breaches in light or dark

  Scenario: A note is dated by the site's day, not UTC's
    Given the post "Hello" carries the edit notes:
      | note           | at                   |
      | late night fix | 2026-09-08T03:00:00Z |
    When I visit "/writing/hello"
    Then ".post-edit-date" includes "Sep 7, 2026"

  Scenario: Two notes from one day show the date once, notes oldest first
    Given the post "Hello" carries the edit notes:
      | note              | at                   |
      | fixed the numbers | 2026-09-07T12:00:00Z |
      | fixed a link      | 2026-09-07T15:00:00Z |
    When I visit "/writing/hello"
    Then the texts of ".post-edit-date" are:
      | Sep 7, 2026 |
    And the texts of ".post-edit-list .post-edit-item" are:
      | fixed the numbers |
      | fixed a link      |

  Scenario: Notes from different days sit under their own dates, newest first, the newest marked dt-updated
    Given the post "Hello" carries the edit notes:
      | note              | at                   |
      | fixed a link      | 2026-09-09T12:00:00Z |
      | fixed the numbers | 2026-09-07T12:00:00Z |
    When I visit "/writing/hello"
    Then the texts of ".post-edit" are:
      | Sep 9, 2026 fixed a link      |
      | Sep 7, 2026 fixed the numbers |
    And the classes of ".post-edit-date time" are:
      | dt-updated |
      |            |

  Scenario: A note's Markdown renders
    Given the post "Hello" carries the edit notes:
      | note                                                   | at                   |
      | fixed `count` and [the link](https://example.com/docs) | 2026-09-07T12:00:00Z |
    When I visit "/writing/hello"
    Then ".post-edit-note code" reads "count"
    And ".post-edit-note" has a link "the link" to "https://example.com/docs"

  Scenario: Raw HTML in a note is escaped
    Given the post "Hello" carries the edit notes:
      | note                               | at                   |
      | fixed <script>alert(1)</script> it | 2026-09-07T12:00:00Z |
    When I visit "/writing/hello"
    Then ".post-edit-note" includes "fixed"
    And the page has no ".post-edit-note script"

  Scenario: A post with no notes, or only another post's, shows no notes block
    Given the posts:
      | title |
      | Other |
    And the post "Other" carries the edit notes:
      | note            |
      | fixed elsewhere |
    When I visit "/writing/hello"
    Then the page has no ".post-edits"
