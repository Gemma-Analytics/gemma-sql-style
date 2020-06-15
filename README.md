# Gemma-SQL-Style
The Gemma SQL style describes our SQL, dbt and jinja2 templating approach.
We like to discuss new styles and approaches, but this guideline should be used
by everyone in Gemma Analytics for internal and client projects.

## Table of contents


  * [Example](#example)
  * [Guidelines](#guidelines)
    + [General conventions](#general-conventions)
      - [Keywords](#keywords)
      - [Name conventions](#name-conventions)
      - [Table name conventions](#table-name-conventions)
      - [Quotation](#quotation)
    + [Line conventions](#line-conventions)
      - [Single line vs multiple line queries](#single-line-vs-multiple-line-queries)
      - [Line character limit](#line-character-limit)
      - [Line alignment](#line-alignment)
      - [When alignment](#when-alignment)
      - [Where alignment](#where-alignment)
      - [Line order conventions](#line-order-conventions)
    + [Join conventions](#join-conventions)
      - [Join general conventions](#join-general-conventions)
      - [Join order](#join-order)
    + [Group conventions](#group-conventions)
      - [Group by style](#group-by-style)
      - [Group by order](#group-by-order)
      - [Lateral column aliasing](#lateral-column-aliasing)
    + [CTEs (Common Table Expressions)](#ctes--common-table-expressions-)
    + [dbt (data build tool)](#dbt--data-build-tool-)
      - [jinja2 macros](#jinja2-macros)
    + [Small things](#small-things)
      - [Field separation](#field-separation)
      - [Equations](#equations)
      - [Parenthesis](#parenthesis)
      - [Long list](#long-list)
      - [Long nested functions](#long-nested-functions)
      - [Window functions](#window-functions)
      - [Boolean conditions](#boolean-conditions)

## Example

  Here's a general query example with most of the guidelines to show a typical
  query at Gemma Analytics.

  ```sql
  WITH users AS (

    SELECT * FROM {{ ref('raw_users') }}

  ), accounts AS (

    SELECT * FROM {{ ref('raw_accounts') }}

  ), number_of_accounts AS (

    SELECT
      user_id
      , created_date

      COUNT(account_id) AS account_count

    FROM accounts
    GROUP BY 1, 2

  ), final AS (

      SELECT
        users.user_id
        , users.type
        , users.group
        , users.created_date
        , number_of_accounts.account_count
        , CASE
            WHEN
              users.type = 'removed' AND
              users.group = 'not_available'
              THEN FALSE
            ELSE TRUE
          END AS is_active
        , ROW_NUMBER() OVER (
            PARTITION BY users.user_id
            ORDER BY users.created_date ASC
          ) AS user_rank
        , {{ some_dbt_macro() }} AS some_field

      FROM users
      LEFT JOIN number_of_accounts ON
        users.user_id = number_of_accounts.user_id
        users.created_date = number_of_accounts.created_date
      WHERE
        users.type != 'test' AND
        users.group IN (
          'Germany',
          'USA',
          'France'
        )
      ORDER BY users.created_date DESC

  )

  SELECT * FROM final
  ```
## Guidelines

### General conventions

#### Keywords

  * Use uppercase for SQL keywords and functions (better 1st sight  separation)
  * Don't use keywords for table, field names and aliases


  ```sql
  -- Good
  SELECT
    user_id
    , type
    , created_at

  FROM test
  WHERE type = 'test'
  ORDER BY user_id ASC

  -- Good
  SELECT
    type
    , COUNT(*) AS amount
  WHERE type = 'test'
  GROUP BY 1

  -- Bad
  select
    type
    , count(*) as amount
  from test
  where type = 'test'
  group by user_id

  ```

#### Name conventions

  * Don't use reserved keywords such as `JOIN`, `date`, etc.
  * Use snake_case (lowercase words, separated by underscore)
  * Rename fields if source table is providing e.g. camelCase
  * Renaming should be on lowest dbt model level -> raw/base models
  * Make especially ids more explicit (user_id instead of id)
  * Boolean fields should be prefixed with `is_`, `has_`, or `does_`
  * Date-only fields should be suffixed with `_date`
  * Datetime fields should be suffixed with `_at`
  * Other date formats like shall also be suffixes like `_month`


  ```sql
  -- Good: field names
  SELECT
    user_id
    , is_active
    , signup_date
    , created_at

  FROM users

  -- Good: base/raw model field renamings
  SELECT
    Id AS user_id
    , user-type AS user_type
    , createdAt AS created_at

  FROM {{ source('example_db', 'users') }}
  ```

  * Use `AS` to alias column names


    ```sql
    -- Good
    SELECT
        user_id
        , email
        , TIMESTAMP_TRUNC(created_at, month) AS signup_month

    FROM users

    -- Bad
    SELECT
        user_id
        , email
        , TIMESTAMP_TRUNC(created_at, month) signup_month

    FROM users
    ```

#### Table name conventions

  * Base/Raw tables/models should be a plural case of the noun
  * Don't abbreviate table names like `users` to `u` and `charges` to `c`
    because it will make the code less readable. Better use shorter CTE names
  * So use full table or CTE name, except you want to join a table more than one
    time. Then you need aliases.


  ```sql
  -- good: table names
  SELECT * FROM users
  SELECT * FROM visit_logs

  -- bad: table names
  SELECT * FROM user
  SELECT * FROM visitLog

  -- good: aliasing
  SELECT
    users.name

    , SUM(charges.amount) AS total_revenue

  FROM users
  INNER JOIN charges ON users.user_id = charges.user_id
  GROUP BY 1

  -- bad: aliasing
  SELECT
    u.name

    , COUNT(c.type) AS total_revenue

  FROM users u
  INNER JOIN charges c ON u.user_id = c.user_id
  GROUP BY 1

  -- exception: multiple joins of same table (silly query)
  SELECT
    users_1.name

    , COUNT(users_2.amount) AS silly_count

  FROM users AS users_1
  INNER JOIN users AS users_2 ON users_1.user_id = users_2.user_id
  GROUP BY 1
  ```


#### Quotation

  * Use single quote notation for string values (also dbt model names)
  * Double quotes are usually used for field and table names (therefore some
    data bases interpret strings as field names)
  * For nested jinja2 templating please also use single quotes


  ```sql
  -- Good
  SELECT
    CASE
      WHEN type = 'test' THEN 1
      ELSE 0
    END AS "is_test_user" -- this is not necessary with snake_CASE
    , DATE(created_at, '{{ var('timezone') }}') AS created_date

  FROM users
  WHERE type != 'error'

  -- Bad
  SELECT
    *
  FROM users
  WHERE type = "test"
  ```

### Line conventions

#### Single line vs multiple line queries

  * Only use single lines when there's no complexity and one thing is selected


  ```sql
  -- Good
  SELECT * FROM users

  -- Good
  SELECT user_id FROM users

  -- Good
  SELECT COUNT(*) FROM users

  -- Bad
  SELECT user_id, CASE WHEN 1 = 1 THEN 1 ELSE 0 END AS test FROM users
  ```

  * Use for every SQL keyword a new line (or keyword groups like `ORDER BY`)
  * Use for every selected field a new line (empty line before `FROM` statement)


  ```sql
  -- Good
  SELECT
    user_id
    , type
    , created_at

  FROM users

  -- Good
  SELECT DISTINCT -- is keyword group
    type

  FROM users
  WHERE email = 'example@domain.com'
  ORDER BY 1 DESC

  -- Good
  SELECT
      type
      , COUNT(*) AS amount

  FROM users
  GROUP BY 1

  -- Bad
  SELECT user_id, type, created_at
  FROM users WHERE type = 'test'

  -- Bad
  SELECT user_id,
      type
  FROM users
  ```

#### Line character limit

  * As in other code languages use 80 characters per line limit
    (example why we should stick to 80 characters
    [link](https://nickjanetakis.com/blog/80-characters-per-line-is-a-standard-worth-sticking-to-even-today))


  ```sql
  -- Good: less than 80 characters
  SELECT
    user_id
    , type
    , created_at
    , CASE
        WHEN 1 = 1 THEN 'test' ELSE 'error'
      END AS test_field

    FROM users

  -- Bad: more than 80 characters
  SELECT user_id, type, created_at, CASE WHEN 1 = 1 THEN 'test' ELSE 'error' END AS test_field
  FROM users
  ```

#### Line alignment

  * Left align SQL keywords
  * Field names and field calculations are to indent
  * Sub-keywords are also to indent (like `WHEN`)
  * Every indention level is 1 tab or 2 whitespaces


  ```sql
  -- Good: aligment
  SELECT
    user_id
    , email

  FROM users
  WHERE email LIKE '%@gmail.com'

  -- Bad
  SELECT user_id, email
    FROM users
   WHERE email LIKE '%@gmail.com'
 ```

#### When alignment

  * Each `WHEN`/`ELSE` of a `CASE` statement should be on its own line.
  * The `THEN` can be on the same line as the `WHEN` keyword if it does fit
    the 80 characters limit. Aim to be consistent here.
  * If a `WHEN` clause has logical operators, move the conditions to own lines


  ```sql
  -- Good:
  SELECT
    CASE
      WHEN event_name = 'viewed_homepage' THEN 'Homepage'
      WHEN event_name = 'viewed_editor' THEN 'Editor'
      ELSE 'Other'
    END AS page_name

  FROM events

  -- Good too
  SELECT
    CASE
      WHEN
        event_name = 'viewed_homepage' OR
        event_name = 'home'
        THEN 'Homepage'
      WHEN
        event_name = 'viewed_editor' AND
        type = 'edit'
        THEN 'Editor'
      ELSE 'Other'
    END AS page_name

  FROM events

  -- Bad
  SELECT
      CASE WHEN event_name = 'viewed_homepage' OR event_name = 'home'
      THEN 'Homepage'
          WHEN event_name = 'viewed_editor' AND type = 'edit 'THEN 'Editor'
          ELSE 'Other'
      END AS page_name

  FROM events
  ```

#### Where alignment
  * When there is only one `WHERE` condition, leave it on the same line
  * With multiple conditions indent those one level deeper and put the logical
    operators at the end of the previous condition
  * For multiple `OR` conditions try to use the `IN` operator if possible


  ```sql
  -- good
  SELECT
    *
  FROM users
  WHERE user_id = 1234

  -- good
  SELECT
    *
  FROM users
  WHERE
    created_at >= '2019-01-01' AND
    type != 'test' AND
    is_active = true
  ORDER BY user_id ASC

  -- bad
  SELECT
    *
  FROM users
  WHERE created_at >= '2019-01-01' AND type != 'test' AND is_active = true
  ORDER BY user_id ASC

  -- good
  SELECT
    *
  FROM users
  WHERE
    created_at >= '2019-01-01' AND
    user_id IN (1234, 2345, 3456, 4567)
  ORDER BY user_id ASC

  -- bad: multiple ORs
  SELECT
    *
  FROM users
  WHERE
    created_at >= '2019-01-01' AND (
    user_id = 1234 OR
    user_id = 2345 OR
    user_id = 3456 OR
    user_id = 4567)
  ORDER BY user_id ASC
  ```

#### Line order conventions

  * Primery key first
  * Foregin keys second
  * String, Integer and Boolean columns
  * Other columns
  * Date(-time) columns
  * With a white space separated the aggregation columns (`MIN`, `SUM`, etc.)
    at the end


  ```sql
  -- Good
  SELECT
      user_id
      , type_id
      , name
      , is_active
      , is_deleted
      , created_at
      , signup_date

      , COUNT(hits) AS number_of_hits
      , MIN(hit_created_at) AS first_event_date

  FROM events
  GROUP BY 1,2,3,4,5,6,7
  -- don't do that, its just for query correctness. see group-by section

  -- Bad
  SELECT
      signup_date
      , type_id
      , MAX(hit_created_at) AS first_event_date
      , created_at
      , name
      , user_id
      , is_active
      , COUNT(hits) AS number_of_hits
      , is_deleted

  FROM users
  GROUP BY 1,2,4,5,6,7,9
  ```

### Join conventions

#### Join general conventions

  * Use in general `LEFT JOIN` as often as possible
  * Use explicit join types (`INNER JOIN` instead of just `JOIN`)
  * Naming of aliases, see [Table name conventions](#table-name-conventions)
  * Single join conditions should be on the same line as the join
  * Alternatively use the `USING` keyword for single condition joins


  ```sql
  -- Good
  SELECT
    users.name

    , COUNT(payment_methods.method_id) AS number_of_payment_methods

  FROM users
  LEFT JOIN payment_methods ON users.user_id = payment_methods.user_id
  GROUP BY 1

  -- Good
  SELECT
    users.name

    , COUNT(payment_methods.method_id) AS number_of_payment_methods

  FROM users
  LEFT JOIN payment_methods USING(user_id)
  GROUP BY 1

  -- Bad
  SELECT
    u.name

    , COUNT(p.method_id) AS number_of_payment_methods

  FROM users u
  JOIN payment_methods p
  ON u.user_id = p.user_id
  GROUP BY 1
  ```

  * Multiple join conditions shall have their own line aligned like in this
    section [Where alignment](#where-alignment)
  * Include the table name when there is a join, but omit it otherwise


  ```sql
  -- Good
  SELECT
    users.name

    , COUNT(payment_methods.amount) AS number_of_payment_methods

  FROM users
  LEFT JOIN payment_methods ON
    users.user_id = payment_methods.user_id AND
    users.created_at = payment_methods.created_at
  GROUP BY 1

  -- Bad
  SELECT
    name

    , COUNT(amount) AS number_of_payment_methods

  FROM users
  LEFT JOIN payment_methods ON
    user_id = user_id AND
    created_at = created_at
  GROUP BY 1
  ```

#### Join order

  * Put the table that is referenced first after the
    `JOIN ... ON` condition
  * This will help determinate fan-out (for more information:
    [fanning-out]("https://discourse.looker.com/t/outer-join-on-false-or-how-i-learned-to-stop-fanning-out-and-love-the-null/4786"))


```sql
-- Good
SELECT
    ...
FROM payment_methods
LEFT JOIN users ON payment_methods.user_id = users.user_id
-- foreign_key = primary_key --> many-to-one --> no fanout

-- Good
SELECT
    ...
FROM users
LEFT JOIN payment_methods ON users.user_id = payment_methods.user_id
-- primary_key = foreign_key --> one-to-many --> fanout

-- Bad
SELECT
    ...
FROM users
LEFT JOIN payment_methods ON payment_methods.user_id = users.user_id

```

### Group conventions

#### Group by style

  * Please group by numbers
  * Try to use as few as possible `GROUP BY` fields. Its a bad sign if you
    group by more than 2-3 fields. Use CTEs instead. Have a read:
    [group-by-1](https://blog.getdbt.com/write-better-sql-a-defense-of-group-by-1/)


  ```sql
  -- Good
  SELECT
    created_date
    , type

    , COUNT(*) AS users_count

  FROM users
  GROUP BY 1, 2

  -- okay
  SELECT
    created_date
    , user_id

    , COUNT(*) AS users_count

  FROM users
  GROUP BY created_date, user_id

  -- Bad
  SELECT
      created_date
      , type

      , COUNT(*) AS users_count

  FROM users
  GROUP BY 1, type
  ```

#### Group by order

  * Grouping columns should go first
  * If there are many fields, follow
    [line-order-convention](#line-order-convention), where the not aggregated
    go first and the aggregated fields last


  ```sql
  -- Good
  SELECT
    TIMESTAMP_TRUNC(created_at, year) AS signup_year

    , COUNT(*) AS total_users

  FROM users
  GROUP BY 1

  -- Bad
  SELECT
    COUNT(*) AS total_users
    , TIMESTAMP_TRUNC(created_at, year) AS signup_year

  FROM users
  GROUP BY 1
  ```

#### Lateral column aliasing

  * Take advantage of lateral column aliasing when grouping by name


  ```sql
  -- Good
  SELECT
    TIMESTAMP_TRUNC(created_at, year) AS signup_year

    , COUNT(*) AS total_users

  FROM users
  GROUP BY 1

  -- Bad
  SELECT
    TIMESTAMP_TRUNC(created_at, year) AS signup_year

    , COUNT(*) AS total_users

  FROM users
  GROUP BY TIMESTAMP_TRUNC(created_at, year)
  ```

### CTEs (Common Table Expressions)

  * Use CTEs instead of subqueries.
    Subqueries are less readable and can't be reused


  ```sql
  -- Good
  WITH test_users AS(

    SELECT
      *
    FROM {{ ref('users') }}
    WHERE type = 'test'

  )

  SELECT COUNT(*) FROM test_users

  -- Bad
  SELECT
    COUNT(*)
  FROM (
    SELECT
      *
    FROM {{ ref('users') }}
    WHERE type = 'test'
  )
  ```

  * Starting and closing CTE parentheses are on the same line
    (easier to out-comment)
  * Always have clean "import" CTEs that just reference to other dbt models.
    This way you make the sources reusable for different calculations
  * Aim to have a final CTE called "final" at the end of the model. It helps to
    have a final CTE while debugging and checking other CTEs.
  * Try to have reasonable CTE names


  ```sql
  -- Good
  WITH source AS(

    SELECT * FROM {{ ref('source') }}

  ), revenue AS(

    SELECT
      id

      , SUM(revenue) AS rev_per_id

    FROM source
    GROUP BY 1

  ), total AS(

    SELECT
      id

      , COUNT(*) AS total_by_id

    FROM source
    GROUP BY 1

  ), final AS(

    SELECT
      source.id
      , revenue.rev_per_id
      , total.total_by_id

    FROM source
    LEFT JOIN revenue ON source.id = revenue.id
    LEFT JOIN total ON source.id = total.id
    WHERE source.type != 'test'

  )

  SELECT * FROM final

  -- Bad
  WITH
  sum_agg AS(

    SELECT
      id

      , SUM(revenue) AS rev_per_id

    FROM {{ ref('source') }}
    GROUP BY 1

  ),

  count_agg AS(

    SELECT
      id

      , COUNT(*) AS total_by_id

    FROM {{ ref('source') }}
    GROUP BY 1

  )

SELECT
  source.id
  , sum_agg.rev_per_id
  , count_agg.total_by_id

FROM {{ ref('source') }}
LEFT JOIN sum_agg ON source.id = sum_agg.id
LEFT JOIN count_agg ON source.id = count_agg.id
WHERE source.type != 'test'
  ```


### dbt (data build tool)

#### jinja2 macros

  * Keep code [DRY](https://docs.getdbt.com/docs/writing-code-in-dbt/macros/) by
    using dbt jinja2 macros
  * Not only it helps keep the code DRY, it also helps to have complex
    calculations in one place and maintain it there
  * For alignment: try to make the dbt SQL code readable, not necessarily the
    compiled SQL code, which is tricky because of the jinja2 whitespacing


  ```sql
  -- Good: complex_macro() is always the same SQL function

  -- the complex_macro in one place:
  {% macro complex_macro() %}

    SUM(revenue*100 - net_error_margin + sidecosts/5)

  {% endmacro %}

  ...

  WITH source AS(

    SELECT * FROM {{ ref('source') }}

  ), revenue_by_date AS(

    SELECT
      created_date

      , {{ complex_macro() }} AS revenue

    FROM source
    GROUP BY 1

  ), revenue_by_type AS(

    SELECT
      type

      , {{ complex_macro() }} AS revenue

    FROM source
    GROUP BY 1

  )

  ...


  -- Bad: we have to write and maintain the calculation in multiple areas
  WITH source AS(

    SELECT * FROM {{ ref('source') }}

  ), revenue_by_date AS(

    SELECT
      created_date

      , SUM(revenue*100 - net_error_margin + sidecosts/5) AS revenue

    FROM source
    GROUP BY 1

  ), revenue_by_type AS(

    SELECT
      type

      , SUM(revenue*100 - net_error_margin + sidecosts/5) AS revenue

    FROM source
    GROUP BY 1

  )

  ...

  ```


### Small things

#### Field separation

  * Put the commas to the beginning of the line


  ```sql
  -- Good
  SELECT
      user_id
      , type
      , created_at

  FROM users
  ```

#### Equations

  * Use `!=` over `<>` (simply because its more readable)



  ```sql
  -- Good
  SELECT
    COUNT(*) AS real_users_count

  FROM users
  WHERE type != 'test'
  ```

#### Parenthesis

  * Avoid spaces inside of parenthesis


  ```sql
  -- Good
  SELECT
    *
  FROM users
  WHERE user_id in (1, 2)

  -- Bad
  SELECT
    *
  FROM users
  WHERE user_id in ( 1, 2 )
  ```

#### Long list

  * Break long lists of `IN` values into multiple indented lines


  ```sql
  -- Good
  SELECT
    *
  FROM users
  WHERE email in (
      'user-1@example.com',
      'user-2@example.com',
      'user-3@example.com',
      'user-4@example.com'
  )
  ```

#### Long nested functions

  * Break long nested functions (dbt macros or just SQL functions) into
    multiple indented lines


  ```sql
  -- Good
  SELECT
    user_id
    , {{ first_dbt_macro(
           second_dbt_macro(
             'some_input_value_1',
             'some_input_value_2',
             'some_input_value_3'
           )
         )
      }} AS macro_field
    , type
    , DATEDIFF(
        day,
        DATETIME(
          timestamp_micros(some_super_long_timestamp),
          'a_super_long_timezone'
        ),
        NOW()
      ) AS date_difference_example

  FROM users
  ```


#### Window functions

  * You can leave it all on its own line or break it up into multiple depending
    on its length ([Line character limit](#line-character-limit)).
    Indention always by 1 tab or 2 whitespaces


  ```sql
  -- Good
  SELECT
    user_id
    , name

    , ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY updated_date DESC)
      AS details_rank

  FROM users

  -- Good
  SELECT
    user_id
    , name

    , ROW_NUMBER() OVER (
        PARTITION BY user_id
        ORDER BY updated_date DESC
      ) AS details_rank

  FROM users
  ```

#### Boolean conditions

  * Be explicit in boolean conditions


  ```sql
  -- Good
  SELECT * FROM customers WHERE is_cancelled = true
  SELECT * FROM customers WHERE is_cancelled = false

  -- Bad
  SELECT * FROM customers WHERE is_cancelled
  SELECT * FROM customers WHERE NOT is_cancelled
  ```
