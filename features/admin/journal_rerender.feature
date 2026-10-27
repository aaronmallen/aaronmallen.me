Feature: Journal re-render
  The rerender job rebuilds each entry's stored HTML from its Markdown, so an entry written before a markup
  change shows it with no edit.

  Scenario: An old entry with a mermaid fence draws its diagram after the job, and a second run changes nothing
    Given I am signed in to the admin
    And I see the page in light mode
    And the journal_entries table holds:
      | entry_date | entry_time | body                                      | body_html  | updated_at           |
      | 2026-10-01 | 09:00:00   | ```mermaid\ngraph TD\n  A-->B\n  A-->C\n``` | <p>old</p> | 2026-10-01T09:00:00Z |
    When the job "Record::Jobs::RerenderJournalEntries" runs
    And I visit "/admin/journal"
    Then the page has 3 of ".journal-days pre.mermaid svg .node"
    And the diagram draws in the light theme
    And the journal_entries table has a row with:
      | updated_at               |
      | 2026-10-01T09:00:00.000Z |
    When the job "Record::Jobs::RerenderJournalEntries" runs
    Then the journal_entries table has a row with:
      | updated_at               |
      | 2026-10-01T09:00:00.000Z |
