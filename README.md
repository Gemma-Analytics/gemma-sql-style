# Gemma-SQL-Style
The Gemma SQL style describes our SQL, dbt and jinja2 templating approach. We like to discuss new styles and approaches, but this guideline should be used by everyone in Gemma Analytics for internal and client projects. Exceptions can be made where a client follows their own style, in which case following their SQL style may be more appropriate.

This style guide is already quite long and still cannot cover every intricacy or special case. In general, the reason to have a SQL style guide is to
- Make our SQL easily readable for ourselves and clients
- Increase development speed by
  * reducing time spent thinking about formatting (it's pre-determined)
  * reducing time spend deciphering SQL, whether in PRs or reading your own old code
  * avoiding slips because missing keywords etc. become more obvious

Therefore, if you are unsure about the formatting, try to format it in a way that appears most suitable for the above.


## Table of contents
* [Example](#example)
* [SQL Guidelines](#sql-guidelines)
  + [General conventions](#general-conventions)
    - [Keywords](#keywords)
    - [Name conventions](#name-conventions)
    - [Table name conventions](#table-name-conventions)
  + [Line conventions](#line-conventions)
    - [Single line vs multiple line queries](#single-line-vs-multiple-line-queries)
    - [Line character limit](#line-character-limit)
    - [Line alignment](#line-alignment)
    - [When alignment](#when-alignment)
    - [Where alignment](#where-alignment)
    - [Line order conventions](#line-order-conventions)
  + [Join conventions](#join-conventions)
    - [Join general conventions](#join-general-conventions)
  + [Group conventions](#group-conventions)
    - [Group by style](#group-by-style)
    - [Lateral column aliasing](#lateral-column-aliasing)
  + [CTEs (Common Table Expressions)](#ctes-common-table-expressions)
  + [Small things](#small-things)
    - [Equations](#equations)
    - [Parenthesis](#parenthesis)
    - [Long list](#long-list)
    - [Long nested functions](#long-nested-functions)
    - [Window functions](#window-functions)
* [dbt Guidelines](#dbt-guidelines)
  + [Model naming](#model-naming)
  + [Model configuration](#model-configuration)
  + [Modeling](#modeling)
  + [Testing](#testing)
  + [Documentation](#documentation)
  + [YAML Style Guide](#yaml-style-guide)
  + [Jinja Style Guide](#jinja-style-guide)

## Example

Here's a general query example including most guidelines to show a typical query at Gemma Analytics.

```sql
WITH users AS (

  SELECT * FROM {{ ref('raw_users') }}

), accounts AS (

  SELECT * FROM {{ ref('raw_accounts') }}

), number_of_accounts AS (

  SELECT
      user_id
    , created_date
    , COUNT(account_id) AS account_count

  FROM accounts
  GROUP BY 1, 2

), final AS (

    SELECT
        users.user_id
      , users.type
      , users.group
      , users.created_date
      , na.account_count
      , NOT (users.type = 'removed' AND users.group = 'not_available') AS is_active
      , ROW_NUMBER() OVER (
          PARTITION BY users.user_id
          ORDER BY users.created_date ASC
        ) AS user_rank
      , {{ some_dbt_macro() }} AS some_field

    FROM users
      LEFT JOIN number_of_accounts AS na
        ON na.user_id = users.user_id
        AND na.created_date = users.created_date
    WHERE users.type != 'test'
      AND users.group IN (
          'Germany'
        , 'USA'
        , 'France'
      )
    ORDER BY users.created_date DESC

)

SELECT * FROM final
```

## SQL Guidelines

### General conventions

#### Keywords

  * Use uppercase for SQL keywords and functions (better 1st sight separation)
  * Don't use keywords for CTEs, tables, field names, and aliases (exception: `final` for the final CTE)


```sql
-- Good
SELECT
    type
  , COUNT(*) AS amount

FROM test
WHERE type = 'test'
GROUP BY 1

-- Bad
select
    type
  , count(*) as amount

from test
where type = 'test'
group by 1
```

#### Name conventions

  * Don't use reserved keywords such as `join`, `from` etc.
  * Use snake_case (all lowercase, only letters and underscores, starting with a letter)
  * Rename fields if source tables do not adhere to these naming conventions
  * A primary key column should be called `id`
  * Renaming should be on lowest dbt model level -> base models
  * Boolean fields should be appropriately prefixed, e.g. with `is_`, `has_`, `was_`, or `does_`
  * Date fields should be suffixed with `_on` or `_date`
  * Timestamp fields should be suffixed with `_at`
  * Timestamp or date fields truncated to a period (e.g. year, quarter, month) should be suffixed with that period, e.g. `_month`
  * Always use `AS` to explicitly alias column names

```sql
-- Good: field names
SELECT
    user_id AS id -- primary key
  , is_active -- type: boolean
  , signup_on -- type: date
  , churn_date -- type: date
  , created_at -- time: timestamp with time zone

FROM users

-- Good: base/raw model field renamings
SELECT
    "Id" AS id
  , "user-type" AS user_type
  , "createdAt" AS created_at

FROM {{ source('example_db', 'users') }}

-- Good
SELECT
      id
    , email
    , TIMESTAMP_TRUNC(created_at, month) AS signup_month

FROM users

-- Bad
SELECT
      user_id
    , "Email"
    , "createdAt" AS created_date -- timestamp with time zone with wrong naming!
    , TIMESTAMP_TRUNC(created_at, month) signup_month

FROM users
```

#### Table name conventions

* Base/Raw tables/models should be a plural case of the noun, but if not at the very least it should be consistent throughout a repository
* If table or CTE names are not concise, use reasonable and short aliases in queries
* If joining the same tables multiple times, try to use aliases relating to the business logic

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
  , SUM(chrg.amount) AS total_revenue

FROM users
  LEFT JOIN user_charges AS chrg
    ON chrg.user_id = users.user_id
GROUP BY 1

-- bad: aliasing
SELECT
    u.name
  , COUNT(c.type) AS total_revenue

FROM users u
  LEFT JOIN charges c
    ON c.user_id = u.user_id
GROUP BY 1

-- good: aliasing with multiple instances of the same table
SELECT
    managers.name AS manager_name
  , employees.name AS employee_name

FROM users AS managers
  LEFT JOIN users AS employees
    ON employees.manager_id = managers.id
WHERE NOT employess.id IS NULL
```

#### Comments

* One-line comments should use the double-dash syntax
* Multi-line comments should use the multi-line syntax with a start and end row
* When writing Jinja in dbt, use Jinja multi-line comments for Jinja-related comments and use SQL comments for SQL-related comments; never use SQL comments in macros!

```sql
-- This is a single-line comment
/*
 *  Multi-line comments are beautiful if you use this syntax instead of multiple
 *  single-line comments or, heaven forbid, starting and ending your multi-line
 *  comment in the same line.
 */

-- two single-line comments
-- are not desirable

/* this is not wanted, either */

/* You could start right away, but it is a matter of beauty and readability to not
start in the first line and use beginning of each line to mark the comment */

{# This is a single-line Jinja comment - use the multi-line syntax #}

{#
 #  Multi-line Jinja comments are the same syntax but use the same multi-line
 #  comment style. You must not use SQL comments in macros because that would
 #  potentially cause issues if the macro is called in a comment!
 #}

```

### Line conventions

#### Single line vs multiple line queries

##### Single Line Queries

  * Only use single lines when there is no complexity and everything or only one field is selected

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

##### Multi-Line Queries

  * New line for every SQL keyword
  * New line for every selected field

```sql
-- Good
SELECT
    user_id
  , type
  , created_at

FROM users

-- Good
SELECT DISTINCT -- exception: DISTINCT can directly follow a SELECT
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

  * As in other code languages use 88 characters per line limit ([here is an article on why we should stick to 88 characters](https://nickjanetakis.com/blog/80-characters-per-line-is-a-standard-worth-sticking-to-even-today) - we prefer 88 over 80, though, as that tends to reduce linebreaks significantly and is still reasonable)


```sql
-- Good: each line is less than 88 characters
SELECT
    user_id
  , type
  , created_at
  , CASE
      WHEN 1 = 1 THEN 'test' ELSE 'error'
    END AS test_field

  FROM users

-- Bad: more than 88 characters
SELECT
    user_id
  , type
  , created_at
  , CASE WHEN this_long_field_name = some_other_field THEN 'test' ELSE 'error' END AS test_field
FROM users
```

#### Line Alignment

  * Left align SQL keywords
  * Field names and field calculations are indented
  * Sub-keywords that belong to a keyword group are also indented
  * Every indention level is 1 tab = 2 spaces
  * The first field name is indentation to the same level as the other field names. It is also acceptable to align it with the subsequent commas.


```sql
-- Good: aligment
SELECT
    user_id
  , email

FROM users
WHERE email LIKE '%@gmail.com'

-- Also acceptable
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
  * The `THEN` can be on the same line as the `WHEN` keyword if it fits the 88 characters limit
  * If a `WHEN` clause has logical operators, move the conditions to their own lines


```sql
-- Good:
SELECT
    event_id
  , CASE
      WHEN event_name = 'viewed_homepage' THEN 'Homepage'
      WHEN event_name = 'viewed_editor' THEN 'Editor'
      ELSE 'Other'
    END AS page_name

FROM events

-- Good:
SELECT
    event_id
  , CASE
      WHEN event_name = 'viewed_homepage'
        OR event_name = 'home'
        THEN 'Homepage'
      WHEN event_name = 'viewed_editor'
        AND type = 'edit'
        THEN 'Editor'
      ELSE 'Other'
    END AS page_name

FROM events

-- Bad
SELECT
    event_id
  , CASE WHEN event_name = 'viewed_homepage' OR event_name = 'home'
    THEN 'Homepage'
        WHEN event_name = 'viewed_editor' AND type = 'edit 'THEN 'Editor'
        ELSE 'Other'
    END AS page_name

FROM events
```

#### Where alignment
* The first condition is on the same level as the `WHERE` keyword
* Each subsequent condition starts with one indentation and the logical operator
* For multiple `OR` conditions try to use the `IN` operator if possible
* Boolean special rules
  - fields can be used without comparison IF their naming is appropriate (e.g. is_active)
  - Negations are at the earliest possible point, e.g. `NOT name IS NULL` instead of `name IS NOT NULL`
  - Use negation where possible (e.g. `NOT name = 'test'` instead of `name != 'test'`)
* Use parentheses abundantly - too many parentheses are better than too few
* Readability is key - if in doubt, and especially if getting complex, choose what's most readable and add comments wherever possible


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
WHERE created_at >= '2019-01-01' -- [add a comment why excluding them here]
  AND NOT type = 'test'
  AND is_active -- no need to write = TRUE
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
WHERE created_at >= '2019-01-01'
  AND user_id IN (1234, 2345, 3456, 4567)
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

* Primary key first
* Foreign keys second
* Attributes next (try to logically group them)
* Metrics at the end
* Optional: Aggregations are separated by an empty line and added at the end


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

* All `JOIN`s are `LEFT JOIN`s
* If we use `INNER JOIN`, we make it explicit (`INNER JOIN` instead of just `JOIN`), and add a comment why - remember, all `JOIN`s are `LEFT JOIN`s @ Gemma unless there is a specific reason to do otherwise! (to avoid `NULL`s doesn't count as a reason: if `NULL`s are not allowed, you must test for it instead of forcing it)
* If we use the `CROSS JOIN`, we make it explicit and add a comment, except for `JSONB` functions such as `JSONB_ARRAY_ELEMENTS()`, which can be cross-joined using the comma notation
* Naming of aliases, see [Table name conventions](#table-name-conventions)
* `JOIN`s are part of the `FROM` keyword group and must be indented accordingly
* All join conditions have their own line, and the joined table's columns always appear on the left side of any condition
* Because our primary keys are usually called `id`, we rarely use the `USING` keyword, but if we do, it is in a new line and indented

```sql
-- Good
SELECT
    users.name
  , COUNT(pm.method_id) AS number_of_payment_methods

FROM users
  LEFT JOIN payment_methods AS pm
    ON pm.user_id = users.user_id
GROUP BY 1

-- Good
SELECT
    users.name

  , COUNT(pm.method_id) AS number_of_payment_methods

FROM users
  LEFT JOIN payment_methods AS pm
    USING(user_id)
GROUP BY 1

-- Good
SELECT
    managers.name
  , employees.name

FROM users AS managers
  LEFT JOIN users AS employees
    ON employees.manager_id = managers.id
    AND NOT employees.branch = managers.branch
WHERE NOT employees.id IS NULL

-- Bad
SELECT
    u.name

  , COUNT(p.method_id) AS number_of_payment_methods

FROM users u
JOIN payment_methods p ON u.user_id = p.user_id
GROUP BY 1
```

### Group conventions

#### Group by style

  * If at all possible, group by referencing the column position(s) with integers
  * Try to use as few as possible `GROUP BY` fields. It is a bad sign if you
    group by more than 2-3 fields. Use CTEs instead. Have a read:
    [group-by-1](https://blog.getdbt.com/write-better-sql-a-defense-of-group-by-1/)
  * In very rare cases it may be necessary to add a field name to the `GROUP BY` fields, in that case add the explicit column name after the integers


```sql
-- Good
SELECT
    created_date
  , type
  , COUNT(*) AS users_count

FROM users
GROUP BY 1, 2

-- Acceptable, but not preferred
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

* Use CTEs instead of subqueries whenever at all possible - subqueries are less readable and cannot be reused
* First-level CTEs start and end with an empty line
* Give your CTEs meaningful names - you can always alias them later if the CTE name is long

```sql
-- Good
WITH test_users AS (

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

* Starting and closing CTE parentheses are on the same line if you have multiple CTEs (easier to out-comment)
* dbt: Always have clean "import" CTEs that consist just of a reference to other dbt models at the start - this way you make it clear which models are references, and the sources are reusable for different calculations within the query
* Optional: When using CTEs, have a final CTE called "final" at the end of the model


```sql
-- Good
WITH orders AS(

  SELECT * FROM {{ ref('orders_model') }}

), revenue AS(

  SELECT
      user_id
    , SUM(revenue) AS rev_per_id

  FROM orders
  GROUP BY 1

), total AS(

  SELECT
      user_id
    , COUNT(*) AS total_by_id

  FROM orders
  GROUP BY 1

), final AS(

  SELECT
      orders.*
    , revenue.rev_per_id
    , total.total_by_id

  FROM orders
    LEFT JOIN revenue
      ON revenue.user_id = orders.user_id
    LEFT JOIN total
      ON total.user_id = orders.user_id
  WHERE NOT source.type = 'test'

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


### Small things

#### Equations

* Use `NOT a = b` or `a != b` over `a <> b` (simply because its more readable)


```sql
-- Good
SELECT
  COUNT(*) AS real_users_count

FROM users
WHERE NOT type = 'test'
```

#### Parenthesis

* Avoid spaces inside of parentheses


```sql
-- Good
SELECT
  *

FROM users
WHERE user_id IN (1, 2)

-- Bad
SELECT
  *

FROM users
WHERE user_id IN ( 1, 2 )
```

#### Long list

* Break long lists of `IN` values into multiple indented lines


```sql
-- Good
SELECT
  *
  
FROM users
WHERE email in ( -- here you can have either trailing or leading commas
  'user-1@example.com',
  'user-2@example.com',
  'user-3@example.com',
  'user-4@example.com'
)
```

#### Long nested functions

* Break long nested functions (dbt macros or just SQL functions) into multiple indented lines


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

* You can leave it on its own line or break it up into multiple ones depending on its length ([Line character limit](#line-character-limit))
* If the window is long, or used more than once, consider defining it using the `WINDOW` keyword

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

-- Good
SELECT
    user_id
  , name
  , ROW_NUMBER() OVER w AS details_rank

FROM users
WINDOW w AS (
  PARTITION BY user_id
  ORDER BY updated_date DESC
)
```


## dbt guidelines

### Model naming 

* The file and naming structure is as follows:
```
analytics
├── dbt_project.yml
└── models
    ├── base
    |    └── stripe
    |        ├── sources.yml
    |        ├── schema.yml
    |        ├── base_stripe_customers.sql
    |        └── base_stripe_invoices.sql
    ├── interim (optional)
    |       └── schema.yml
    |       └── customers_all.sql
    ├── analytics
    |   └── core # optional folder names
    |   |   └── schema.yml
    |   |   └── dim_customers.sql
    |   |   └── fact_orders.sql
    |   └── marketing # optional folder names
    ├── reporting (optional)
    |       └── daily_management_metrics.sql
    └── export
        └── braze #reverse etl schema
```
* All objects should be plural, such as: `base_stripe_invoices`

* Base tables are prefixed with `base_`, such as: `base_<source>_<object>`

* Analytics tables are categorized between facts and dimensions with a prefix that indicates either, such as: `fact_orders` or `dim_customers`

* Table names should reflect granularity e.g. `orders` should have one order per row and `daily_orders` should have one day per row.

* Reporting tables should refer to specific reports or KPIs that are used for the visualisation tool

* Export tables hold data will be loaded into third-party tools via a reverse ETL process (db service users of the tools should only have access to that schema)


### Model configuration

* If a particular configuration applies to all models in a directory, it should be specified in the `dbt_project.yml` file.

* The default materialization should be tables.

* Model-specific attributes (like sort/dist keys) should be specified in the model.

* In-model configurations should be specified like this at the top of the model:
```
{{
  config(
    materialized = 'table',
    sort = 'id',
    dist = 'id'
  )
}}
```

### Modeling

* Only `base_` models should select from sources.

* All other models should only select from other models.

* CTEs that are duplicated across models should be pulled out into their own models.

* Only `base_` models should:

  * rename fields to meet above naming standards.

  * cast foreign keys and other fields so they can be used uniformly across the project.

  * contain minimal transformations that are 100% guaranteed to be useful for the foreseeable future. An example of this is parsing out the Salesforce ID from a field known to have messy data.

  * If you need more complex transformations to make the source useful, consider adding an `interim_` table.

* Only `interim_` models should:

  * use aggregates, window functions, joins necessary to clean data for use in upstream models.

  * contain transformations that fundamentally alter the meaning of a column.

### Testing

* The primary key of each model must be tested with `unique` and `not_null` tests. 

* Use the [dbt utils](https://github.com/dbt-labs/dbt-utils/tree/0.1.7/#schema-tests) and [great expectations](https://github.com/calogica/dbt-expectations/tree/0.1.2/) community packages for tests.

* Source models:

  * Freshness [tests](https://docs.getdbt.com/reference/resource-properties/freshness) help monitor sources where the ETL tool does not allow for this.
```
version: 2

sources:
  - name: stripe
    freshness:
      warn_after:
        count: 1
        period: day
      error_after:
        count: 36
        period: hour
    loaded_at_field: _sdc_extracted_at
```
  * Additional column value tests can be added to ensure that data inputs conform to your expectations.

 * Distributional [tests](https://github.com/calogica/dbt-expectations/tree/0.1.2/#distributional-functions) help monitor unreliable ETL sources.

* Transformations should:

  * be validated in the BI tool, preferably against a predefined acceptance criteria.

  * Additional column value tests are recommended for `interim_` tables and complex transformations.

### Documentation

* Depending on the BI tool, tables that are exposed in the BI tool should be documented for end users. Whenever possible, reporting table documentation should contain the metadata needed to sync dbt documentation from the dbt `.yml` file to the reporting tool. 

  * Explain what the table contains – e.g. `fact_orders` described as `Represents an individual order`.

  * Note what was filtered out from the table.

  * Primary keys and foreign keys do not need to be documented if their origin is clear – e.g. `shopify_customer_id` will not be mixed up with `stripe_customer_id`.

 * Add an explanation to every new field that was not in the source table:

   * Explain how metrics are calculated.

   * Specify the origin of new dimension fields – e.g. if you generated a label called `market` that uses a `COALESCE` between shipping and billing country names, explain that.

* Pro tip: you can copy and paste documentation from Fivetran’s dbt [packages](https://hub.getdbt.com/), which cover many sources   

* For source tables, we will rely on the API documentation. Optionally, you can add a link to the ETL repo.

* For seeds relying on GoogleSheets, add the URL the documentation for debugging failures.

* Use inline comments for any confusing or implicit logic that cannot be understood from the code alone.

### YAML style guide

* Indents should be two spaces

* List items should be indented

* Use a new line to separate list items that are dictionaries where appropriate
```
version: 2

models:
  - name: events
    columns:
      - name: event_id
        description: This is a unique identifier for the event
        tests:
          - unique
          - not_null

      - name: event_time
        description: "When the event occurred in UTC (eg. 2018-01-01 12:00:00)"
        tests:
          - not_null

      - name: user_id
        description: The ID of the user who recorded the event
        tests:
          - not_null
          - relationships:
              to: ref('users')
              field: id
```
### Jinja style guide

* When using Jinja delimiters, use spaces on the inside of your delimiter, like `{{ this }}` instead of `{{this}}`

* Use newlines to visually indicate logical blocks of Jinja.

* Keep code [DRY](https://docs.getdbt.com/docs/building-a-dbt-project/jinja-macros) by using dbt Jinja macros.

* Not only it helps keep the code DRY, it also helps to have complex calculations in one place and maintain it there.

* Be mindful of excessive `for` loops that create performance issues in SQL.

* For alignment: try to make the dbt SQL code readable, not necessarily the compiled SQL code, which is tricky because of the jinja2 whitespacing
```
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