Feature: Heading anchors
  A link to a heading scrolls it to just below the top of the window, clear of the header.

  Scenario: A heading anchor scrolls the heading to just below the top of the window
    Given a long post "Hello" with the heading "Where it lands" in the middle
    When I visit "/writing/hello#where-it-lands"
    Then the top of "#where-it-lands" sits 96 pixels down the window
