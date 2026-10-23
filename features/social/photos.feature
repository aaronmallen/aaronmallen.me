Feature: Photos on social posts
  Each part of a social post holds up to four photos, in order, each with its own alt text.

  Background:
    Given Mastodon and Bluesky are connected
    And I am signed in to the admin
    And the photos table holds:
      | key                                  | width | height | byte_size | created_at  |
      | 00000000000000000000000000000001.png | 10    | 10     | 100       | 3 days ago  |
      | 00000000000000000000000000000002.png | 10    | 10     | 100       | 3 days ago  |
      | 00000000000000000000000000000003.png | 10    | 10     | 100       | 3 days ago  |
      | 00000000000000000000000000000004.png | 10    | 10     | 100       | 3 days ago  |
      | 00000000000000000000000000000005.png | 10    | 10     | 100       | 3 days ago  |

  Scenario: With a media store each part offers a photo picker that uploads to the admin
    When I visit "/admin/social"
    Then the social page has 1 "[data-social-part] [data-social-photo-pick]"
    And the social page has 1 "[data-social-part] [data-social-photos][data-social-upload='/admin/photos']"

  Scenario: A draft keeps each photo in order with its alt text, and one with none
    When I send the social composer:
      | parts  | one                                          |
      | photos | part 1 photo 2 'A dog', part 1 photo 1 'A cat', part 1 photo 3 |
      | intent | draft                                        |
    Then the social photos held are "part 1 photo 2 'A dog', part 1 photo 1 'A cat', part 1 photo 3"
    And the photo claims read "part 1 photo 2, part 1 photo 1, part 1 photo 3"

  Scenario: A photo stays on the part that holds it, past a blank part
    When I send the social composer:
      | parts  | one //  // three |
      | photos | part 3 photo 1   |
      | intent | draft            |
    Then the social photos held are "part 2 photo 1"

  Scenario: A save that lists no photos drops them and their claims, one that leaves the field out keeps them
    When I send the social composer:
      | parts  | one // two                      |
      | photos | part 1 photo 1, part 2 photo 2  |
      | intent | draft                           |
    And I send the social composer:
      | to     | /admin/social/1 |
      | parts  | one // two      |
      | photos | part 2 photo 2  |
      | intent | draft           |
    Then the social photos held are "part 2 photo 2"
    And the photo claims read "part 2 photo 2"
    When I send the social composer:
      | to     | /admin/social/1  |
      | parts  | edited // two    |
      | intent | draft            |
    Then the social photos held are "part 2 photo 2"
    And the photo claims read "part 2 photo 2"
    When I send the social composer:
      | to     | /admin/social/1 |
      | parts  | one             |
      | photos |                 |
      | intent | draft           |
    Then the social photos held are ""

  Scenario: The same photo may sit on two parts, and each part takes four
    When I send the social composer:
      | parts  | one // two                                                                                                         |
      | photos | part 1 photo 1, part 1 photo 2, part 1 photo 3, part 1 photo 4, part 2 photo 1, part 2 photo 2, part 2 photo 3, part 2 photo 4 |
      | intent | draft                                                                                                              |
    Then there are 1 social posts

  Scenario Outline: Photos it will not take are refused, kept in the form, and nothing is saved
    When I send the social composer:
      | parts  | <parts>  |
      | photos | <photos> |
      | intent | draft    |
    Then the social page answered 422
    And the social composer says "<error>"
    And the social photos held are ""

    Examples:
      | parts    | photos                                                                         | error                                            |
      | one      | part 1 photo 1, part 1 photo 2, part 1 photo 3, part 1 photo 4, part 1 photo 5 | A part takes four photos at most.                |
      | one      | part 1 photo 1, part 1 photo 1                                                 | A part holds each photo once.                    |
      | one // { *0} | part 2 photo 1                                                                 | Write something in each part that holds photos. |
      | one      | part 3 photo 1                                                                 | Write something in each part that holds photos. |

  Scenario: A refused post keeps the photos and their alt text in the form
    When I send the social composer:
      | parts  | one                                                                                                          |
      | photos | part 1 photo 1 'Photo 0', part 1 photo 2 'Photo 1', part 1 photo 3 'Photo 2', part 1 photo 4 'Photo 3', part 1 photo 5 'Photo 4' |
      | intent | draft                                                                                                        |
    Then the social photo alt texts read "Photo 0, Photo 1, Photo 2, Photo 3, Photo 4"

  Scenario: A key no photo carries is refused
    When I send the social composer with a photo key no photo carries
    Then the social composer says "A photo is gone. Remove it and add it again."

  Scenario: Editing shows each photo in order with its alt text, in the preview and counted
    When I send the social composer:
      | parts  | one // two                                     |
      | photos | part 1 photo 1 'A cat', part 1 photo 2, part 2 photo 3 |
      | intent | draft                                          |
    And I open social post 1 in the composer
    Then the social composer photos read "part 1 photo 1, part 1 photo 2, part 2 photo 3"
    And the social photo alt texts read "A cat, , "
    And the social page shows "Photos 2/4" in "[data-social-photo-count]"
    And the social preview photos read "A cat, , "
    And the page has no axe breaches in light or dark

  Scenario Outline: The queue shows each item's photos under their parts, in order
    Given the social posts:
      | text      | status   |
      | one // two | <status> |
    And the social_post_photos table holds:
      | social_post_part_id | position | photo_key                            | alt_text |
      | 2                   | 1        | 00000000000000000000000000000003.png | A bird   |
      | 1                   | 1        | 00000000000000000000000000000002.png | A dog    |
      | 1                   | 2        | 00000000000000000000000000000001.png | A cat    |
    When I open the social page at "?filter=<filter>"
    Then the social queue photos read "photo 2 'A dog', photo 1 'A cat', photo 3 'A bird'"
    And the social page has 1 ".sq-part + .sq-photos + .sq-part + .sq-photos .sq-photo[alt='A bird']"
    And the page has no axe breaches in light or dark

    Examples:
      | status    | filter |
      | scheduled | queued |
      | draft     | drafts |
      | posted    | posted |

  Scenario: An item with no photos shows none
    Given the social posts:
      | text       | status    |
      | one // two | scheduled |
    When I visit "/admin/social"
    Then the social page has 2 ".sq-part"
    And the social page has no ".sq-photos"

  Scenario: Removing a post releases its photos and deletes a photo nothing else holds
    When I send the social composer:
      | parts  | one            |
      | photos | part 1 photo 1 |
      | intent | draft          |
    And I remove social post 1 from the drafts queue
    Then the social photos held are ""
    And the photo_claims table holds 0 rows
    And the photos table has no row with:
      | key                                  |
      | 00000000000000000000000000000001.png |

  Scenario: Removing a post keeps a photo another post holds
    When I send the social composer:
      | parts  | one            |
      | photos | part 1 photo 1 |
      | intent | draft          |
    And I send the social composer:
      | parts  | two            |
      | photos | part 1 photo 1 |
      | intent | draft          |
    And I remove social post 2 from the drafts queue
    Then the photo claims read "part 1 photo 1"
    And the photos table holds 5 rows

  Scenario: A save that drops a part releases and deletes its photos
    When I send the social composer:
      | parts  | one // two     |
      | photos | part 2 photo 1 |
      | intent | draft          |
    And I send the social composer:
      | to     | /admin/social/1 |
      | parts  | one             |
      | intent | draft           |
    Then the social photos held are ""
    And the photo_claims table holds 0 rows
    And the photos table holds 4 rows

  Scenario: The sweep keeps a photo while a part holds it
    When I send the social composer:
      | parts  | one            |
      | photos | part 1 photo 1 |
      | intent | draft          |
    And the job "Media::Jobs::SweepPhotos" runs
    Then the photos table holds 1 rows

  Scenario: The database refuses a fifth photo on a part
    When I send the social composer:
      | parts  | one                                                            |
      | photos | part 1 photo 1, part 1 photo 2, part 1 photo 3, part 1 photo 4 |
      | intent | draft                                                          |
    Then the database refuses photo 5 at position 5 on part 1

  Scenario: Accepting a suggestion that rewrites a part keeps its photos
    When I send the social composer:
      | parts  | one // two     |
      | photos | part 1 photo 1 |
      | intent | draft          |
    And the suggestions table holds:
      | social_post_id |
      | 1              |
    And the suggestion_edits table holds:
      | suggestion_id | position | part | original | replacement | reason | status  |
      | 1             | 1        | 1    | one      | edited      | typo   | pending |
    And I accept the suggestions on social post 1 from the admin
    Then social post 1 has the parts "edited // two"
    And the social photos held are "part 1 photo 1"
