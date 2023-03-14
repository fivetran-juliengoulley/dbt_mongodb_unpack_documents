<p align="center">
    <a alt="License"
        href="https://github.com/fivetran/dbt_mongo_formula_utils/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" /></a>
    <a alt="dbt-core">
        <img src="https://img.shields.io/badge/dbt_Core™_version-=1.3.1-orange.svg" /></a>
    <a alt="Maintained?">
        <img src="https://img.shields.io/badge/Maintained%3F-no-orange.svg" /></a>
    <a alt="PRs">
        <img src="https://img.shields.io/badge/Contributions-welcome-blueviolet" /></a>
</p>

# Fivetran MongoDB Flatten Documents Utils
# 📣 What does this dbt package do?
This package includes macros and scripts to be used within a dbt project to flatten json and array documents. It is designed to  work with data from [Fivetran's MongoDB connector](https://fivetran.com/docs/databases/mongodb) "packed mode" described by [this documentation](https://fivetran.com/docs/databases/mongodb#packedmode).

# 🎯 How do I use the dbt package?
## Step 1: Prerequisites
To use this dbt package, you must have the following:
- At least one Fivetran MongoDB connector syncing data into your destination.
- A **SQL Server** destination.

## Step 2: Define database and schema variables
By default, this package runs using your destination and the `mongo` schema. If this is not where your MongoDB data is (for example, if your MongoDD schema is named `mongo_fivetran`), add the following configuration to your root `dbt_project.yml` file:

```yml
vars:
    mongo_database: your_database_name
    mongo_schema: your_schema_name
```

## Step 3: Define required source tables
In order to use the macros included in this package, you will need to have a properly configured MongoDB source named `mongo` in your own dbt project. An example of a properly configured mongo source yml can be found in the `src_mongo.yml` file in [integration_tests](https://github.com/fivetran/dbt_mongo_formula_utils/blob/main/integration_tests/models/src_fivetran_formula.yml). This integration_tests folder is just for testing purposes - your source file will need to be in the models folder of your root dbt project. You are welcome to copy/paste the [example](https://github.com/fivetran/dbt_mongo_formula_utils/blob/main/integration_tests/models/src_fivetran_formula.yml) source configuration into your `src_mongo.yml` file and modify for your use case.

In particular, you will need the following sources defined in your `src_mongo.yml` file:
```yml
version: 2

sources:
  - name: mongo # It would be best to keep this named mongo
    database: {{ var('mongo_database', target.database) }} # Configure the database where your MongoDB data resides if different from the target database. Eg. 'my_mongo_database'. By default the target.database is used.
    schema: "{{ var('mongo_schema', 'mongo') }}" # Configure the mongo_schema var from your dbt_project.yml (alternatively you can hard-code the schema here if only using one MongoDB connector)
    tables:
      - name: my_first_table # Duplicate this section, configure the table name and keep the columns section as is
        columns:
          - name: id
            description: System-generated unique ID of the active volume measurement.
          - name: data
            description: the packed data
      - name: my_second_table
        columns:
          - name: id
            description: System-generated unique ID of the active volume measurement.
          - name: data
            description: the packed data      
      ## Any other source tables you are creating models for should be defined here as well. They aren't required, but it is best organizational practice and allows Fivetran to compile data lineage graphs
```

## Step 4: Create models
### (Recommended and default) Option 1: flatten all fields including arrays

If you would like your model to flatten the entire document at once related to your source table then you will need to:
1. Create a new file in your models folder and name it `your_table_name_here.sql` (e.g. `customer.sql`; this is not necessary but recommended as best practice).
2. Add the below snippet calling the [`generate_flatten_json`](https://github.com/fivetran/dbt_mongo_formula_utils#mongodb_formula_view-source) macro into the file. Update the `source_table` argument to be the source table name for which you are generating the model (e.g. `customer`). Though `mode` is explicitly included here, it is `flatten_array` by default.
```sql
{{
  generate_flatten_json(
    model_name = source('mongo', 'source_table'),
    json_column = 'data',
    mode = 'flatten_array'
  )
}}
```

> This option makes use of the `fivetran_formula_model` lookup table, which stores connector-generated SQL queries for each source table. Compared to `fivetran_formula`, which is used in Options 2 & 3, it is typically more complete and supports most double-nested formulas.

### Option 2: Flatten all fields but arrays

If you would like your model to flatten the document but store arrays in singular fields then you will need to:
1. Create a new file in your models folder and name it `your_table_name_here.sql` (e.g. `customer.sql`; this is not necessary but recommended as best practice).
2. Add the below snippet calling the [`generate_flatten_json`](https://github.com/fivetran/dbt_mongo_formula_utils#mongodb_formula_view-source) macro into the file. Update the `source_table` argument to be the source table name for which you are generating the model (e.g. `customer`).
```sql
{{
  generate_flatten_json(
    model_name = source('mongo', 'source_table'),
    json_column = 'data',
    mode = 'do_not_flatten_array'
  )
}}
```

> This option makes use of the `fivetran_formula` lookup table, which requires the package to combine fields' formulas into a SQL query for each source table. This option does not support double-nested formulas and therefore may be incomplete compared to Option #1.

### Option 3: Flatten arrays only

If you would like your model to arrays (generated by Option 2) then you will need to:
1. Create a new file in your models folder and name it `your_array_table_name_here.sql` (e.g. `customer_addresses.sql`; this is not necessary but recommended as best practice).
2. Add the below snippet calling the [`generate_flatten_array`](https://github.com/fivetran/dbt_mongo_formula_utils#mongodb_formula_view-source) macro into the file.
    - Update the `source_model` argument to be the source model name for which you are flattening the array (e.g. model name from Step 2).
    - Update the `column_name` argument to be the column name containing the array to flatten(e.g. `addresses`).
```sql
{{
  generate_flatten_array(
    model_name =  ref('source_model'),
    json_column = 'column_name'
  )
}}
```

## Step 4: Execute models
Once you have created all your desired models and copied/modified the sql snippet into each model you will execute `dbt run` to generate the models.

## (Optional) Step 5: Orchestrate your models with Fivetran Transformations for dbt Core™
<details><summary>Expand to view details</summary>
<br>

Fivetran offers the ability for you to orchestrate your dbt project through [Fivetran Transformations for dbt Core™](https://fivetran.com/docs/transformations/dbt). Learn how to set up your project for orchestration through Fivetran in our [Transformations for dbt Core setup guides](https://fivetran.com/docs/transformations/dbt#setupguide).
</details>

# :book: Macro & script documentation

## generate_flatten_json ([source](macros/generate_flatten_json.sql))
This macro flattens the packed document (json) generated by the MongoDB connector to the desired table.

**Usage:**
```sql
{{
  generate_flatten_json(
    model_name = source('mongo', 'source_table'),
    json_column = 'data',
    mode = 'flatten_array'
  )
}}
```
**Args:**
* `source_table` (required): The table containing the data to flatten.
* `json_column` (required): The table containing the packed data. Set to data when using "Packed/Standard mode"
* `mode` (optional, default = `flatten_array`): Defines whether arrays are flattened or stored in a single column. Supported values are `flatten_array` and `do_not_flatten_array`
----

## generate_flatten_array ([source](macros/generate_flatten_array.sql))
This macro flattens the packed document (json) generated by the MongoDB connector to the desired table.

**Usage:**
```sql
{{
  generate_flatten_array(
    model_name =  ref('source_model'),
    json_column = 'column_name'
  )
}}
```
**Args:**
* `source_model` (required): The model containing the array to flatten.
* `column_name` (required): The name of the column containing the array


# 🔍 Does this package have dependencies?
This dbt package is dependent on the following dbt packages. Please be aware that these dependencies are installed by default within this package. For more information on the following packages, refer to the [dbt hub](https://hub.getdbt.com/) site.
No

# 🙌 How is this package maintained and can I contribute?
## Package Maintenance
There is no maintenance of this package

## Contributions
Contributions are welcome

# 🏪 Are there any resources available?
- Have questions or want to just say hi? Raise an [issue](https://github.com/fivetran-juliengoulley/.../issues)
