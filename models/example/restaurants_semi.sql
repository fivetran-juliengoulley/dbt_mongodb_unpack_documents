{{
  generate_flatten_json(
    model_name = source('mongo', 'restaurants'),
    json_column = 'data',
    mode = 'no_flatten_array'
  )
}}
