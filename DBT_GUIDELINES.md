# Gemma's dbt guidelines
The Gemma dbt guidelines describe the architecture of the Gemma dbt projects.

A dbt project is a collaborative artifact and for it to be usable and durable, the rules for creating it must be clear. 
When a project is structured clearly and consistently, it becomes easier to read, easier to debug, and much easier to build upon. It gives others a map they can follow, whether they’re reviewing your work, contributing to it, or just trying to understand what’s going on. A well-defined project ensures that everyone’s working from the same plan, helping projects faster and teammates collaborate better, to stay focused on solving the real problems and reduce maintenance work.

The goal of this guide is to define clear, up-to-date best practices for structuring dbt projects and to explain the rationale behind each recommendation. 

It does not cover SQL & jinja style, which are covered by the [Gemma SQL Style Guide](https://github.com/Gemma-Analytics/gemma-sql-style/blob/12c7ee25428cc336423acc224a189dba47f7f002/README.md)

## Table of contents
* [dbt project structure](#dbt-project-structure)
  + [base/](#base/)
  + [interim/](#interim/)
  + [reporting/](#reporting/)
  + [export/](#export/)
* [Model naming](#model-naming)
* [Model configuration](#model-configuration)
* [Modeling](#modeling)
* [Testing](#testing)
* [Snapshots](#snapshots)
* [Documentation](#documentation)
  + [Model-level documentation](#model-level-documentation/)
  + [Column-level documentation](#column-level-documentation/)
  + [Tests documentation](#tests-documentation/)
  + [In-line documentation](#in-line-documentation)
* [YAML Style Guide](#yaml-style-guide)
* [Jinja Style Guide](#jinja-style-guide)

## dbt project structure
* The file and naming structure is as follows:
```
gemma-analytics
├── README.md
├── analyses
├── seeds
│   └── seed_channels_mapping.csv
├── dbt_project.yml
├── macros
│   └── cents_to_dollars.sql
└── models
    ├── base
    |    └── stripe
    |        ├── _sources.yml
    |        ├── _base_stripe_docs
    |        |   └── base_stripe_customers.md
    |        |   └── base_stripe_invoices.md
    |        ├── _base_stripe_schemas
    |        |   └── base_stripe_customers.yml
    |        |   └── base_stripe_invoices.yml
    |        ├── base_stripe_customers.sql
    |        └── base_stripe_invoices.sql
    ├── interim 
    |       ├── _interim_docs
    |       |   └── interim_customers.md
    |       ├── _interim_schemas
    |       |   └── interim_customers.md
    |       └── interim_customers.sql
    ├── reporting
    |       ├── core
    |       |   └── fact
    |       |   |   ├── _fact_docs
    |       |   |   |   └── fact_orders.md
    |       |   |   ├── _fact_schemas
    |       |   |   |   └── fact_orders.md
    |       |   |   ├── fact_orders.sql
    |       |   └── dim
    |       |       ├── ...
    |       |       └── dim_customers.sql
    |       └── finance (optional)  
    |           ├── ...
    |           └── profit_and_loss.sql
    ├──  export
    |   ├── ...    
    |   └── export_braze #reverse etl schema
    ├── packages.yml
    ├── snapshots
    └── data_tests
        └── test_orders_tax_amount_discrepancy.sql

```
All transformation models are housed in the models/ folder and follow a layered structure that enforces a clean, directional flow of data. Models should flow from base → interim → reporting → export, with no reverse dependencies.

> A clear folder structure in dbt ensures clean data flow, improves maintainability, and supports best practices. It also enables folder-level configurations (e.g., materializations), permissions (e.g. only finance should have access to specific tables) and allows you to run or test specific parts of the project (e.g., `dbt run --s reporting/` ).

### base/
The purpose of this layer is to isolate and standardize raw data before any business logic is applied. These are raw source models, one-to-one with source tables (e.g., Stripe). 
The transformations in the base layer should be:
* Field renaming
* Type casting (*Always make sure to cast ids to string!*)
* Light cleaning (e.g., date parsing)

There should be one folder per source with:
* The related base models
* The `base_<source>_docs folder`, containing the md files of the models
* The `base_<source>_schemas folder`, containing the yml files of the models
* The `sources.yml` files for that source

### interim/
The interim layer serves as a preparatory stage between raw base models and final reporting models. It’s where we do the heavy lifting of business logic, including:
* Applying complex cleaning logic
* Joining multiple models
* Staging reusable logic used across multiple reporting models
* Calculating derived fields that aren’t raw but also aren’t aggregates
* Preparing data before aggregations

The folder structure for the interim/ layer depends on the number of data sources and the complexity of your transformations and use cases.
A few common structures include:
* By data source (e.g. `stripe/`, `shopify/`, `braze/`)
* By domain or subject area, if that better reflects the business use cases (e.g. `marketing/`)

What is important is to keep folder-level permissions and configs in mind when deciding and choose a structure that makes it easy to:
* Understand where logic lives
* Reuse and test components easily
* Onboard quickly without guesswork

### reporting/
This layer contains production-grade models exposed to downstream tools and stakeholders.
Keep the reporting/core layer as lean as possible, it should mainly contain final aggregations and reshaped outputs for BI tools or business users. All the intermediate wrangling, logic, and transformations should happen in interim.
This approach promotes:
* Reusability: The same interim model can feed multiple reporting models.
* Modularity: Each model does one thing well.
* Debuggability: Easier to test and trace logic in isolation.

The folder structure should be:
* `core/fact/`: Central fact tables like fact_orders
* `core/dim/`: Dimension tables like dim_customers
* `<department/use case>/` (optional): Subject-specific reporting such as `profit_and_loss.sql`

### export/
The export layer contains models specifically designed to prepare data for syncing back into external operational tools — such as CRM platforms (e.g., Salesforce, HubSpot), marketing automation tools (e.g., Braze, Klaviyo), or customer support systems (e.g., Zendesk). 
These models should not introduce new business logic, they are purely about formatting and structuring data for delivery to external systems. All logic should already be handled upstream in interim or reporting.

The folder structure should be by target tool (e.g. `salesforce/`, `klaviyo/`)

## Model naming 
Consistent and descriptive model names are essential for a maintainable dbt project. Good naming helps quickly understand a model’s purpose, fits naturally into documentation and lineage graphs, and makes it easier to debug, extend, or reuse models over time.

> Guideline: Model names should clearly reflect what the model contains and optionally where it fits in the transformation flow, not just the source system or table it came from.

The key best-practices to follow when naming models are the following:
* All objects should be plural, such as: `base_stripe_invoices`

* Base tables are prefixed with `base_`, such as: `base_<source>_<object>` and Interim tables are prefixed with `interim_`, such as `interim_<source>_<object>`

* Reporting core tables are categorized between facts and dimensions with a prefix that indicates either, such as: `fact_orders` or `dim_customers`

* Table names should reflect granularity e.g. `orders` should have one order per row and `daily_orders` should have one day per row.

* Non-core reporting tables should refer to specific reports or KPIs that are used for the visualisation tool

* Export tables hold data that will be loaded into third-party tools via a reverse ETL process (db service users of the tools should only have access to that schema)

## Model configuration
Model configurations in dbt control how your models are built, stored, and described. They’re an important part of keeping your project efficient and aligned with how the data should be used.

You can set configurations:
* Globally by folder in dbt_project.yml (great for setting defaults like ephemeral for interim models)
* Locally within a model using {{ config(...) }} (useful for exceptions or overrides)

> Guideline: Set sensible defaults at the folder level and override them at the model level only when necessary, consistency keeps the project easier to reason about.

The key best-practices to follow when configuring models are the following:
* If a particular configuration applies to all models in a directory, it should be specified in the `dbt_project.yml` 

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

## Modeling
Modeling is at the heart of a dbt project: it’s where we transform raw data into clean, meaningful, and business-ready datasets. Good modeling isn’t just about writing SQL, it’s about designing datasets that are trustworthy, easy to use, and aligned with how the business thinks.

> Guideline: A well-modeled dataset answers real business questions, follows consistent patterns, and minimizes duplication of logic across the project. The goal is to build a project where:
> - Each model has a clear, single responsibility
> - Business logic lives in one place
> - Changes are easy to trace and test

The key best-practices to follow when modeling are the following:
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

For style guidelines read the [Gemma SQL Style Guide](https://github.com/Gemma-Analytics/gemma-sql-style/blob/12c7ee25428cc336423acc224a189dba47f7f002/README.md)


## Testing
As projects scale, ensuring data reliability across pipelines becomes increasingly complex, but also more critical. Poor data quality can erode trust, lead to bad decisions, and create costly rework. A good testing strategy helps us systematically catch and resolve issues before they reach end users, without being overwhelmed with noise and alert fatigue.

> Guideline: When approaching testing strategy, keep in mind the following goals:
> - Proactive Issue Detection: Catch data issues early by implementing targeted tests at key stages of your pipeline.
> - Targeted Ownership & Triage: Route alerts directly to the person or team best equipped to investigate and resolve the issue.
> - Efficient Troubleshooting: Prevent alert fatigue by prioritizing high-impact issues and minimizing false positives.

Read the [Gemma data quality framework](https://gemmaanalytics.atlassian.net/wiki/spaces/TEC/pages/2598010911/Data+Quality+Framework) for a more complete overview of testing strategy.

Here are some key testing guidelines:
* The primary key of each model must be tested with `unique` and `not_null` tests. 

* Use the [dbt utils](https://github.com/dbt-labs/dbt-utils/tree/0.1.7/#schema-tests) and [great expectations](https://github.com/calogica/dbt-expectations/tree/0.1.2/) community packages for tests.

* Source models:
  * Freshness [tests](https://docs.getdbt.com/reference/resource-properties/freshness) help monitor sources where the ETL tool does not allow for this.
```
version: 2

sources:
  - name: stripe
    config:
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

## Snapshots
Snapshots are used to track how specific rows in a table evolve over time, making them ideal for capturing slowly changing dimensions (SCDs) such as customer status, subscription tier, or pricing plans.

That said, not every table needs a snapshot. They are best used when:
* The source system doesn’t maintain historical data
* You need to track field-level changes
* You want to know what changed and when

> Guideline: Think of snapshots as **immutable history logs**. They should be kept simple and direct: avoid applying filters, transformations, or joins. Introducing logic into snapshots adds complexity and can obscure the actual changes in the data.

In most cases, **snapshots should be built directly on raw source tables** (`source(...)`).  
This ensures you capture the original state of the data without relying on any upstream transformation logic, which could break or evolve over time.

> Cleaning or correcting a broken snapshot is very tricky, it's better to snapshot cleanly and simply from the start.

## Documentation

Documentation is just as important as clean SQL or proper testing. It isn’t just about writing descriptions; it’s about creating a living, breathing map of your data transformations. Good documentation:
* Provides clarity on data lineage - Traces data from source to consumption
* Helps new team members understand complex transformations - Reduces onboarding time
* Acts as a self-service resource for analysts and stakeholders - Reduces ad-hoc questions
* Supports data governance and compliance efforts - Critical for regulated industries
* Improves data quality - Well-documented data is typically better understood and maintained

In this section, we focus on four key types of documentation:
* **Model-level documentation** — what the model represents
* **Column-level documentation** — what each field represents
* **Tests documentation** — what is being tested and how to debug failures
* **In-code documentation** — why the logic / model is written the way it is

Depending on the BI tool, tables and fields that are exposed in the BI tool should be documented for end users. Whenever possible, reporting table documentation should contain the metadata needed to sync dbt documentation from the dbt `.yml` file or model configs to the reporting tool.

> Check out the [Automated documentation confluence page](https://gemmaanalytics.atlassian.net/wiki/spaces/TEC/pages/2711420951/Automated+dbt+documentation+with+dbt-invoke-gemma) to test automating the process with the gemma-dbt-invoke package (note that the package is still in the testing phase)

### Model-level documentation

The model-level documentation should live in the `<model_name>.yml` file in the related `<path>_schemas` folder.

**Best Practices**
* Explain what the table contains – e.g. `fact_orders` described as `Represents an individual order`.
* Note what was filtered out from the table.
* For source tables, we will rely on the API documentation. Optionally, you can add a link to the ETL repo.
* Use the meta field to store additional model-level information that can be used internally or by external tools like data catalogs and dashboards. This structured metadata can improve documentation and enable automation.
* For models relying on GoogleSheets, add the URL to the documentation for debugging failures.

**Example**
```
version: 2

models:

- name: fact_order_lines
    description: >
      This fact table contains one row per individual line item in a customer order, combining product, pricing, and channel-level detail. It is the most granular representation of transactional order data, used for revenue attribution, AOV analysis, channel performance, and inventory insights.
      Each row represents a single product SKU purchased as part of an order, enriched with attributes from the product, customer, and sales channel dimensions.
      Joinable with dim_customers, dim_products, dim_channels via surrogate keys.
      Grain: 1 row per order line item (`item_line_id`)
    config:
      meta:
        business_owner: "finance_team"
        status: "pending_review"
    columns:
      - name: ORDER_PURCHASED_ON
        description: |-
          {{ doc("base_amazon_order_lines__ORDER_PURCHASED_ON") }}
        data_tests: 
        ...
```

### Column-level documentation

The field-level documentation should be filled out in the `<model_name>.md` file in the related `<path>_docs` folder of the model which it is created and added to the  `<model_name>.yml` file in the related `<path>_schemas` folder for all models in which the column appears. This allows to document individual columns with precise, informative descriptions. It’s very useful because each time you want to document the `net_sales` column in different models I can use the {{ doc() }} function

**Best Practices**
* Pro tip: you can copy and paste documentation from Fivetran’s dbt [packages](https://hub.getdbt.com/), which cover many sources 
* Primary keys and foreign keys do not need to be documented if their origin is clear – e.g. `shopify_customer_id` will not be mixed up with `amazon_customer_id`, however, if you have a `customer_id` field because you union the tables, this should be documented.
* Add an explanation to every new field created:
  * Explain how metrics are calculated.
  * Specify the origin of new dimension fields – e.g. if you generated a label called `market` that uses a `COALESCE` between shipping and billing country names, explain that.

**Examples**

In the md file

```
{% docs interm_business_central_article_sales_INVOICE_NUMBER %}
Composite key created by concatenating CUSTOMER_ID and INVOICE_NUMBER with ',' as separator. Used to uniquely identify sales records.
Sources: business_central
{% enddocs %}

{% docs interm_business_central_article_sales_INVOICE_DATE %}
Date of the sale, derived from the created_at column.
Sources: business_central
{% enddocs %}
```

In the yml file

```
version: 2

models:

- name: fact_invoices
    description: >
      (model description)
    meta:
      business_owner: "finance_team"
      status: "pending_review"
    columns:
      - name: INVOICE_NUMBER
        description: >
           {{ doc("interm_business_central_article_sales_INVOICE_NUMBER") }}
        data_tests: 
        ...
```

The field-level documentation can be pushed to the DHW with the following code snippet in the `dbt_project.yml` file:

```
+persist_docs: 
      relation: true # Add comments to tables/views
      columns: true # Add comments to columns
      
```

### Tests documentation
Tests are only valuable if people understand what they check and why they exist. Documenting your tests helps teams debug faster, avoid redundant or conflicting checks, and maintain trust in the data quality framework. Test descriptions can also be used to push alerts directly to stakeholders to keep them informed or when the issue lies in wrong manual input in the source data.

We document tests in two places:
* **In `.yml` files generic tests**
* **In the `.sql` file for custom tests**

**Best Practices**
Add info on:
* What is being tested
* Likely failure reasons
* How to troubleshoot
* Who 'owns' the troubleshooting
* Who should be alerted

> Pro tip: If you add this info as `meta` fields it can be easily added to alert failures and/or data quality dashboards

**Examples**

Generic tests

```
version: 2

models:

- name: base_gsheets_business_targets
  description: >
      (model description)
  meta:
    business_owner: "finance_team"
    status: "production"
  columns:
    - name: UID 
      description: >
        {{ doc("base_gsheets_business_targets_UID") }}
      data_tests: 
        - unique:
            config:
              meta:
                  description: >
                    "If this test fails there are multiple rows with the same month and channel in the business_targets ghseets"
                  resolution_steps: >
                    "remove the duplicated data"
                  failure_owner: "finance_team"
                  cc_failure_alert: "analytics_engineering"                
      ...
```
Custom tests

```
{{ config(
    severity = "error"
    , tags = ["finance", "revenue"]
    , meta = {
        "description": "This test verifies that net_revenue is correctly calculated as 
            gross_revenue - discount_amount on each order line"

        , "resolution_steps": "Investigate the discount_amount or net_revenue logic 
            in the model and upstream source tables (interim_amazon_order_lines and interim_shopify_order_lines) and check that business rules are applied consistently."

        , "failure_owner": "analytics_engineering"

        , "cc_failure_alert": "finance_team"
    }
) }}

SELECT * FROM {{ ref("fact_order_lines") }}
WHERE ABS(net_revenue - (gross_revenue - discount_amount)) > 0.01
```
  
### In-line documentation
Clear in-line documentation is essential to:
* Help your future self and teammates understand logic and intent without reverse-engineering SQL
* Speed up onboarding of new team members or external collaborators
* Support better debugging and maintenance when business logic changes
* Complement dbt's structured YAML documentation with technical helpful context and commentary

**Best Practices**
* Add comments for any confusing or implicit logic that cannot be understood from the code alone.
* For complex models, add a comment at the beginning of the model with the details on code structure and important info which are not documented in the yml files.

**Examples**
Document implicit logic
 ```
 WHERE type IN ('refund_line', 'order_line')
    /*
     * Filter by date instead or order_id, because an order might have been placed 
     * sometime before we started tracking web and app data, but a product was refunded
     * after we started tracking. If we filter by order_id, those cases would ne be 
     * considered, and we would underestimate the refunded_item_quantity
    */
    AND day_date >= '2024-02-01'
```

Document structure of complex model
```
/* MODEL STRUCTURE
 *
 * INPUT DATA
 * - order_items
 * - seed_variation_mapping
 * - seed_markup_fix
 * - seed_product_group_anomalies
 * - seed_payment_method_map
 * 
 * PRODUCT GROUP ANOMALIES
 * Fixing product groups which were incorrectly assigned via a seed file.
 *
 * DISCOUNT ATTRIBUTION
 * We assign the discount amount to the order items in proportion to the item revenue share.
 * After assigning the discount, we remove the amount that has been assigned to the product 
 * from the discount line 
 * See discount_adjusted_price_total_gross and discount_adjusted_price_total_net columns.
 * Relevant CTEs:
 * - products_revenue: isolates 'product' line items and calcluates the total order revenue 
 *   from products
 * - discounts_amount: isolates 'discount' line items, excluding delivery discounts
 * - assigned_discounts_amounts: joins products_revenue and discounts_amount on order_id
 *   to calculate the discount amount assigned to each product in proportion to the product revenue share 
 * - discounts_aggregation: calculates the total assigned amount per discount by aggregating 
 *   assigned_discounts_amounts on the item_line_id of the discount
 * - products_aggregation: calculates the total assigned amount per product by aggregating 
 *   assigned_discounts_amounts on the item_line_id of the product
 * - order_items_enriched: joins the base table with products_aggregation and discounts_aggregation 
 *   on item_line_id to calculate the discount adjusted price for each order item. 
 *   The discount adjusted values move the discount amount (if attributed) from the the discount 
 *   line items to the product line items.                         
 * 
 * PAYMENT METHOD MAPPING
 * We map the payment method to the payment method category with a seed table.
 *
 * COGS MARKUP FIX
 * We fix the cogs markup for some items with a seed table.
 *
 */

 ```

## YAML style guide

**Best Practices**
* Indents should be two spaces
* List items should be indented
* Use a new line to separate list items that are dictionaries where appropriate

**Examples**
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


## Jinja style guide

**Best Practices**

* When using Jinja delimiters, use spaces on the inside of your delimiter, like `{{ this }}` instead of `{{this}}`
* Use newlines to visually indicate logical blocks of Jinja.
* Keep code [DRY](https://docs.getdbt.com/docs/building-a-dbt-project/jinja-macros) by using dbt Jinja macros.
* Not only it helps keep the code DRY, it also helps to have complex calculations in one place and maintain it there.
* Be mindful of excessive `for` loops that create performance issues in SQL.
* For alignment: try to make the dbt SQL code readable, not necessarily the compiled SQL code, which is tricky because of the jinja2 whitespacing

**Examples**

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
