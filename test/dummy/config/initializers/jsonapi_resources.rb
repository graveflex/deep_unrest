JSONAPI.configure do |config|
  #:underscored_key, :camelized_key, :dasherized_key, or custom
  config.json_key_format = :camelized_key
  config.default_exclude_links = [:self]
end
