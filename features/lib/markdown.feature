Feature: Markdown headings on a post
  A post's Markdown headings render with ids and no anchor links, a level one heading drops to h2 since the
  page owns the h1, and the contents list names each h2.

  Scenario: A post's headings render with ids, and the contents list each h2
    Given a published post "Engines" whose Markdown body is:
      """
      # Title

      ## The `config` file

      ### Deeper

      ## "Fast" & loose

      ##

      ## See [the docs](https://example.org)

      ## Setup

      ## Setup
      """
    When the rerender posts job runs
    And I read the post "Engines"
    Then the post's headings are:
      | level | id              | text            |
      | h2    | title           | Title           |
      | h2    | the-config-file | The config file |
      | h3    | deeper          | Deeper          |
      | h2    | fast--loose     | "Fast" & loose  |
      | h2    |                 |                 |
      | h2    | see-the-docs    | See the docs    |
      | h2    | setup           | Setup           |
      | h2    | setup-1         | Setup           |
    And no heading holds an anchor link
    And the contents list "Title, The config file, \"Fast\" & loose, See the docs, Setup, Setup"
    And the page has no axe breaches in light or dark

  Scenario: A post with no h2 shows no contents list
    Given a published post "Plain" whose Markdown body is:
      """
      plain text
      """
    When the rerender posts job runs
    And I read the post "Plain"
    Then the post shows no contents list
