Feature: Project keys
  Each project carries a short key of capital letters and digits, unique across projects, which the
  database fills from the name when none is given.

  Scenario Outline: A project key must be two to six capital letters and digits, starting with a letter
    Then the database refuses, breaking a check constraint:
      """
      insert into projects (name, visibility, key) values ('pod', 'public', '<key>')
      """

    Examples:
      | key     |
      | pod     |
      | P       |
      | POD-1   |
      | 1POD    |
      | PODCAST |

  Scenario: Two projects cannot share a key
    Given the database runs:
      """
      insert into projects (name, visibility, key) values ('first', 'public', 'POD')
      """
    Then the database refuses, breaking a unique constraint:
      """
      insert into projects (name, visibility, key) values ('second', 'public', 'POD')
      """

  Scenario: A project whose key is cleared gets one from its name, in id order
    Given the database runs:
      """
      insert into projects (name, visibility, key) values ('pod', 'public', 'AA'), ('pod', 'public', 'BB'), ('pod', 'public', 'CC');
      update projects set key = null where id = 1;
      update projects set key = null where id = 2;
      update projects set key = null where id = 3;
      """
    Then the database answers "POD, POD2, POD3" for:
      """
      select string_agg(key, ', ' order by id) from projects
      """

  Scenario: A project with no letters in its name gets the key PRJ
    Given the database runs:
      """
      insert into projects (name, visibility) values ('42', 'public')
      """
    Then the database answers "PRJ" for:
      """
      select key from projects
      """
