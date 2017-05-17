# DeepUnrest
Short description and motivation.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'deep_unrest'
```

And then execute:
```bash
$ bundle
```

## Configuration
1. Mount the endpoint:

    ```ruby
    # config/routes.rb
    Rails.application.routes.draw do
      # ...
      mount DeepUnrest::Engine => '/deep_unrest'
    end
    ```

2. Set the authentication concern and authorization strategy:

    ```ruby
    # config/initailizers/deep_unrest.rb
    DeepUnrest.configure do |config|
      # concern that will be included by the conroller to authenticat the user
      config.authentication_concern = DeviseTokenAuth::Concerns::SetUserByToken

      # method that will be called from the controller to identify the current user
      config.get_user = proc { current_user }

      # or if your app has multiple user types:
      # config.get_user = proc { current_admin || current_user }

      # stategy that will be used to authorize the current user for each resource
      self.authorization_strategy = DeepUnrest::Authorization::PunditStrategy
    end
    ```

## Usage

#### Example 1 (Simple Update):

Update a single `Submission` with id `123`

##### Request:

```javascript
// PATCH /deep_unrest/update
{
  redirect: '/api/submissions/123',
  data: [
    {
      path: 'submissions.123',
      attributes: {
        name: 'foo'
      }
    }
  ]
}
```

##### 200 Response:
The success action is to follow the `redirect` request param
(`/api/submissions/123` in the example above).

```javascript
{
  id: 123,
  type: 'submissions',
  attributes: {
    name: 'foo'
  }
}
```

##### 403 Response:
```javascript
[
  {
    source: { pointer: { 'submissions.123' } },
    title: "User with id '456' is not authorized to update Submission with id '123'"
  }
]
```

##### 405 Response:
```javascript
[
  {
    source: { pointer: { 'submissions.123' } },
    title: 
  }
]

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
