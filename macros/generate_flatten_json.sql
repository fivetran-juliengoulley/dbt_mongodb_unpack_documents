{% macro generate_flatten_json(model_name, json_column, mode) %}

{% set get_json_path %}

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
{# /* get the unique paths and types */ #}
select [Path] as json_path, max([type]) as json_type
from low_level_flatten
where ([type]<4 and [Path] not like '%[[]%')
{% if mode == 'flatten_array' %}
  or [type]<4
{% else %}
  or ([type]=4 and [Path] not like '%[[]%')
{% endif %}
group by [Path]
order by [Path] asc

{% endset %}


{# /* explode JSON columns and format the column names  */ #}
{% set table = run_query(get_json_path) %}

{% if execute %}
    {% set table_rows = table.rows %}
{% else %}
    {% set res_list = [] %}
{% endif %}

select
{% for table_row in table_rows %}
    {{ table_row.json_path | replace(".", "_") | replace("[", "_") | replace("]", "") | replace("'", "") | replace("$_", "flat_") | replace('"', "") }} as {{ table_row.json_path | replace(".", "_") | replace("[", "_") | replace("]", "") | replace("'", "") | replace("$_", "") | replace('"', "") }}{{ ", " if not loop.last else "" }}
{% endfor %}
from {{ model_name }}
CROSS APPLY OPENJSON({{ model_name }}.{{json_column}})
WITH (
  {% for table_row in table_rows %}
    {{ table_row.json_path | replace(".", "_") | replace("[", "_") | replace("]", "") | replace("'", "") | replace("$_", "flat_") | replace('"', "") }} {{ " nvarchar(max)" if table_row.json_type == 4 else " varchar(max)" }} '{{table_row.json_path}}' {{ " as JSON" if table_row.json_type == 4 else "" }}{{ ", " if not loop.last else "" }}
  {% endfor %}
);

{% endmacro %}
