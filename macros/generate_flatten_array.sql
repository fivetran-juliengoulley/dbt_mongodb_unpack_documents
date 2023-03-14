{% macro generate_flatten_array(model_name, json_column) %}

{% set get_array_path %}

{# /* get json keys and paths with the OPENJSON function supported by SQL Server */ #}
with low_level_flatten(_id,[Path],[PathWithoutIndex],[key],[value],[type])as(
  select _id,[Path]=cast(concat('$."',[key],'"') as nvarchar(max)),[PathWithoutIndex]=cast(concat('$."',[key],'"') as nvarchar(max)),[key],[value],[type]
  from {{model_name}}
    outer apply openjson({{model_name}}.{{json_column}})
  union all
  select _id,[Path]=cast((case when low_level_flatten.[type]=4 then concat(low_level_flatten.[Path],'[',k.[key],']') else concat(low_level_flatten.[Path],'."',k.[key],'"') end) as nvarchar(max)),
    [PathWithoutIndex]=cast((case when low_level_flatten.[type]=4 then concat(low_level_flatten.[PathWithoutIndex],'[]') else concat(low_level_flatten.[PathWithoutIndex],'."',k.[key],'"') end) as nvarchar(max)),
    k.[key],k.[value],k.[type]
  from low_level_flatten
    outer apply openjson(low_level_flatten.[value]) k
  where low_level_flatten.[type]>3
)

, array_paths as (
  select _id, [key] as array_id, [value] as array_value
  from low_level_flatten
  where [type]=5
)
{# /* get the array keys and paths with the OPENJSON function supported by SQL Server */ #}
, array_paths_flatten(_id,array_id,[Path],[PathWithoutIndex],[key],[value],[type])as(
  select _id,array_id,[Path]=cast(concat('$."',[key],'"') as nvarchar(max)),[PathWithoutIndex]=cast(concat('$."',[key],'"') as nvarchar(max)),[key],[value],[type]
  from array_paths t
    outer apply openjson(t.array_value)
  union all
  select _id,array_id,[Path]=cast((case when array_paths_flatten.[type]=4 then concat(array_paths_flatten.[Path],'[',k.[key],']') else concat(array_paths_flatten.[Path],'."',k.[key],'"') end) as nvarchar(max)),
    [PathWithoutIndex]=cast((case when array_paths_flatten.[type]=4 then concat(array_paths_flatten.[PathWithoutIndex],'[]') else concat(array_paths_flatten.[PathWithoutIndex],'."',k.[key],'"') end) as nvarchar(max)),
    k.[key],k.[value],k.[type]
  from array_paths_flatten
    outer apply openjson(array_paths_flatten.[value]) k
  where array_paths_flatten.[type]>3
)
{# /* get the unique and flattest paths */ #}
select distinct [Path] as json_path, max([type]) as json_type
from array_paths_flatten
where [type]<4
group by [Path]
order by [Path] asc

{% endset %}

{# /* explode JSON columns and format the column names  */ #}
{% set table = run_query(get_array_path) %}

{% if execute %}
    {% set table_rows = table.rows %}
{% else %}
    {% set res_list = [] %}
{% endif %}

with low_level_flatten(_id,[Path],[PathWithoutIndex],[key],[value],[type])as(
  select _id,[Path]=cast(concat('$."',[key],'"') as nvarchar(max)),[PathWithoutIndex]=cast(concat('$."',[key],'"') as nvarchar(max)),[key],[value],[type]
  from {{model_name}}
   outer apply openjson({{model_name}}.{{json_column}})
  union all
  select _id,[Path]=cast((case when low_level_flatten.[type]=4 then concat(low_level_flatten.[Path],'[',k.[key],']') else concat(low_level_flatten.[Path],'."',k.[key],'"') end) as nvarchar(max)),
   [PathWithoutIndex]=cast((case when low_level_flatten.[type]=4 then concat(low_level_flatten.[PathWithoutIndex],'[]') else concat(low_level_flatten.[PathWithoutIndex],'."',k.[key],'"') end) as nvarchar(max)),
   k.[key],k.[value],k.[type]
  from low_level_flatten
   outer apply openjson(low_level_flatten.[value]) k
  where low_level_flatten.[type]>3
)
, json_paths as (
  select _id, [key] as array_id, [value] as array_value
  from low_level_flatten
  where [type]=5
)

select _id,array_id,

{% for table_row in table_rows %}
    {{ table_row.json_path | replace(".", "_") | replace("[", "_") | replace("]", "") | replace("'", "") | replace("$_", "flat_") | replace('"', "") }} as {{ table_row.json_path | replace(".", "_") | replace("[", "_") | replace("]", "") | replace("'", "") | replace("$_", "") | replace('"', "") }}{{ ", " if not loop.last else "" }}
{% endfor %}

from json_paths

CROSS APPLY OPENJSON(json_paths.array_value)

WITH (
  {% for table_row in table_rows %}
    {{ table_row.json_path | replace(".", "_") | replace("[", "_") | replace("]", "") | replace("'", "") | replace("$_", "flat_") | replace('"', "") }} {{ " nvarchar(max)" if table_row.json_type == 4 else " varchar(max)" }} '{{table_row.json_path}}' {{ " as JSON" if table_row.json_type == 4 else "" }}{{ ", " if not loop.last else "" }}
  {% endfor %}
);

{% endmacro %}
