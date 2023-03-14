{{
  generate_flatten_json(
    model_name = source('mongo', 'restaurants'),
    json_column = 'data',
    mode = 'flatten_array'
  )
}}
