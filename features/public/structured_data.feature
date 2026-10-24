Feature: Structured data
  Post pages and the home page describe themselves to search engines in JSON-LD.

  Scenario: A post with nothing of its own is described as a blog post
    Given the posts:
      | title | body                  | tags | published            | updated              |
      | Hello | The opening paragraph | ruby | 2026-09-17T15:30:00Z | 2026-09-18T09:00:00Z |
    When I visit "/writing/hello"
    Then the structured data on the page is:
      """
      [{
        "@context": "https://schema.org",
        "@type": "BlogPosting",
        "headline": "Hello",
        "description": "The opening paragraph",
        "datePublished": "2026-09-17T15:30:00Z",
        "dateModified": "2026-09-18T09:00:00Z",
        "author": {"@type": "Person", "@id": "{site}/#owner", "name": "Aaron Allen", "url": "{site}/"},
        "url": "{site}/writing/hello",
        "mainEntityOfPage": "{site}/writing/hello",
        "keywords": ["ruby"]
      }]
      """

  Scenario: A post with its own card carries its image, canonical link and summary, and no keywords
    Given the posts:
      | title                  | slug  | summary          | image                        | canonical                       |
      | </script><b>Hello</b>  | hello | What it is about | https://example.com/card.png | https://elsewhere.example/hello |
    When I visit "/writing/hello"
    Then the structured data holds "image" as "https://example.com/card.png"
    And the structured data holds "url" as "https://elsewhere.example/hello"
    And the structured data holds "description" as "What it is about"
    And the structured data holds "headline" as "</script><b>Hello</b>"
    And the structured data has no "keywords"

  Scenario: The home page describes the site and its owner with their profiles
    When I visit "/"
    Then the structured data on the page is:
      """
      [{
        "@context": "https://schema.org",
        "@graph": [
          {"@type": "WebSite", "@id": "{site}/#website", "url": "{site}/", "name": "Aaron Allen", "publisher": {"@id": "{site}/#owner"}},
          {"@type": "Person", "@id": "{site}/#owner", "name": "Aaron Allen", "url": "{site}/",
            "sameAs": ["https://github.com/aaronmallen", "https://bsky.app/profile/aaronmallen.dev", "https://ruby.social/@aaronmallen"]}
        ]
      }]
      """

  Scenario: A page with no structured data of its own renders none
    When I visit "/privacy"
    Then the structured data on the page is:
      """
      []
      """
