Feature: Media the owner sees
  A photo no published post shows is the owner's alone: the owner's browser gets it and keeps it an hour, and a
  browser that holds it gets a 304 that never asks the store. A width of such a photo stays hidden even from the
  owner, and a key that is no photo key answers the owner the way it answers anyone.

  Background:
    Given the photos:
      | key                                  | width | height | widths   |
      | a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg | 1500  | 1000   | 640,1280 |
    And I am signed in to the admin

  Scenario Outline: A photo no published post shows, when <owner>, is the owner's, kept an hour in their browser alone
    Given the photo setup "<owner>"
    And the media store holds "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 200
    And the body is:
      """
      photo a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg
      """
    And the "Content-Type" header is "image/jpeg"
    And the "Cache-Control" header is "private, max-age=3600"
    Given my requests send the header "If-None-Match" as "\"a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg\""
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 304
    And the "Cache-Control" header is "private, max-age=3600"

    Examples:
      | owner                                               |
      | no record claims it                                 |
      | a draft post claims it                              |
      | a scheduled post claims it                          |
      | a journal entry claims it                           |
      | a task that is gone claims it                       |
      | a task on an unpublished board claims it            |
      | a task on a private project's board claims it       |
      | a task on no project claims it                      |
      | a comment on a task off a published board claims it |

  Scenario: A photo a published post shows keeps its public cache when the owner asks for it
    Given the posts:
      | title |
      | Shown |
    And the photo "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" is claimed by:
      | owner | record |
      | post  | Shown  |
    And the media store holds "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 200
    And the "Cache-Control" header is "public, max-age=31536000, s-maxage=86400, immutable"

  Scenario: A width of a photo no published post shows answers 404 even to the owner
    Given the photo setup "a draft post claims it"
    When I request "/media/640/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 404

  Scenario: A key that is no photo key keeps its 404 a minute for the owner too
    When I request "/media/a1b2c3.jpg"
    Then it answers 404
    And the "Cache-Control" header is "public, max-age=60"
