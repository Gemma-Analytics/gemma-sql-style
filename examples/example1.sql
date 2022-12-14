-- Example taken from README.md

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