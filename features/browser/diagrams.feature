Feature: Diagrams
  A mermaid fence draws as an SVG diagram in the site's theme, on the post page and in the admin preview, from
  code the site serves and only on pages that hold one.

  Scenario Outline: A mermaid fence on the public post page draws a diagram in <scheme> mode
    Given the posts:
      | title | body                                      |
      | Hello | ```mermaid\ngraph TD\n  A-->B\n  A-->C\n``` |
    And I see the page in <scheme> mode
    When I visit "/writing/hello"
    Then the diagram draws in the <scheme> theme
    And the page has 3 of "pre.mermaid svg .node"
    And the page has no "pre.mermaid .hl-ln"
    And the page has no "pre.syntax-highlighting"

    Examples:
      | scheme |
      | light  |
      | dark   |

  Scenario: Switching the theme redraws the diagram
    Given the posts:
      | title | body                              |
      | Hello | ```mermaid\ngraph TD\n  A-->B\n``` |
    And I see the page in light mode
    When I visit "/writing/hello"
    Then the diagram draws in the light theme
    When I click the element "[data-theme-toggle]"
    Then the diagram draws in the dark theme
    When I click the element "[data-theme-toggle]"
    Then the diagram draws in the light theme

  Scenario: A change to the system theme redraws the diagram
    Given the posts:
      | title | body                              |
      | Hello | ```mermaid\ngraph TD\n  A-->B\n``` |
    And I see the page in light mode
    When I visit "/writing/hello"
    Then the diagram draws in the light theme
    Given I see the page in dark mode
    Then the diagram draws in the dark theme

  Scenario: A page with no mermaid fence loads no mermaid code
    Given the posts:
      | title | body                        |
      | Hello | ```ruby\nNAME = "create"\n``` |
    When I visit "/writing/hello"
    Then the page has "pre.syntax-highlighting"
    And the page loads no mermaid code

  Scenario: The diagram draws under the content security policy with no script from another host
    Given the posts:
      | title | body                              |
      | Hello | ```mermaid\ngraph TD\n  A-->B\n``` |
    Then a browser that keeps to the content security policy draws the diagram on "/writing/hello" from the site alone

  Scenario: A mermaid fence in the admin preview draws a diagram that follows the theme
    Given I am signed in to the admin
    And I see the page in light mode
    When I visit "/admin/posts/new"
    And I write the post body:
      """
      ```mermaid
      graph TD
        A-->B
      ```
      """
    And I choose the "Preview" option
    Then the page has ".preview pre.mermaid svg .node"
    And the diagram draws in the light theme
    Given I see the page in dark mode
    Then the diagram draws in the dark theme

  Scenario: A mermaid fence in an artifact draws a diagram
    Given I am signed in to the admin
    And the agent writes the notes "Schema" with the body "```mermaid\ngraph TD\n  A-->B\n```"
    And I see the page in light mode
    When I visit "/admin/agents/artifacts/{artifact}"
    Then the diagram draws in the light theme
    And the page has 2 of "pre.mermaid svg .node"
