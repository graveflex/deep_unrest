# Deep UnREST

[![CircleCI](https://circleci.com/gh/graveflex/deep_unrest.svg?style=svg)](https://circleci.com/gh/graveflex/deep_unrest)
[![Test Coverage](https://codeclimate.com/repos/591cc05fbd15c32ce10014b4/badges/36013471f0d2c4c6f875/coverage.svg)](https://codeclimate.com/repos/591cc05fbd15c32ce10014b4/coverage)
[![Code Climate](https://codeclimate.com/repos/591cc05fbd15c32ce10014b4/badges/36013471f0d2c4c6f875/gpa.svg)](https://codeclimate.com/repos/591cc05fbd15c32ce10014b4/feed)
[![Issue Count](https://codeclimate.com/repos/591cc05fbd15c32ce10014b4/badges/36013471f0d2c4c6f875/issue_count.svg)](https://codeclimate.com/repos/591cc05fbd15c32ce10014b4/feed)

<img src="/docs/img/logo.png" width="100%">

Perform updates on deeply nested resources as well as bulk operations.

## Goals

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
      # will be included by the controller as a concern
      config.authentication_concern = DeviseTokenAuth::Concerns::SetUserByToken

      # will be called from the controller to identify the current user
      config.get_user = proc { current_user }

      # or if your app has multiple user types:
      # config.get_user = proc { current_admin || current_user }

      # stategy that will be used to authorize the current user for each resource
      self.authorization_strategy = DeepUnrest::Authorization::PunditStrategy
    end
    ```

## Usage

### Example 1 - Simple Update:
Update attributes on a single `Submission` with id `123`

##### Request:

```javascript
// PATCH /deep_unrest/update
{
  redirect: '/api/submissions/123',
  data: [
    {
      path: 'submissions.123',
      attributes: {
        approved: true
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
    approved: 'true'
  }
}
```

##### 403 Response:
This error will occur when a user attempts to update a resource that is not
within their policy scope.

```javascript
[
  {
    source: { pointer: { 'submissions.123' } },
    title: "User with id '456' is not authorized to update Submission with id '123'"
  }
]
```

##### 405 Response:
This error will occur when a is allowed to update a resource, but not
specified attributes of that resource.

```javascript
[
  {
    source: { pointer: { 'submissions.123' } },
    title: "Attributes [:approved] of Submission not allowed to Applicant with id '789'"
  }
]
```

##### 409 Response:
This error will occur when field-level validation fails on any resource
updates.

```javascript
[
  {
    source: { pointer: { 'submissions.123.name' } },
    title: 'Name is required',
    detail: 'is required',
  }
]
```

### Example 2 - Simple Delete:
To delete a resource, pass the param `destroy: true` along with the path to that resource.

##### Request:
```javascript
// PATCH /deep_unrest/update
{
  data: [
    {
      path: 'submissions.123',
      destroy: true,
    }
  ]
}
```

##### 200 Response:
When no redirect path is specified, an empty object will be returned as the
response.

```javascript
{}
```

### Example 3 - Simple Create:
When creating new resources, the client should assign a temporary ID to the new
resource. The temporary ID should be surrounded in brackets (`[]`).

##### Create Request
```javascript
// PATCH /deep_unrest/update
{
  data: [
    {
      path: 'submissions[1]',
      attributes: {
        name: 'testing'
      }
    }
  ]
}
```

##### Create Errors:
All errors regarding the new resource will use the temp ID as the path to the error.

```javascript
[
  {
    source: { pointer: { 'submissions[123].name' } },
    title: 'Name is invalid',
    detail: 'is invalid',
  }
]
```

### Example 4 - Complex Nested Update:

This shows an example of a complex operation involving multiple resources. This
example will perform the following operations:

* Change the `name` column of `Submission` with id `123` to `test`
* Change the `value` column of `Answer` with id `1` to `yes`
* Create a new `Answer` with a value of `No` using temp ID `[1]`
* Delete the `Answer` with id `2`

These operations will be performed within a single `ActiveRecord` transaction.

##### Complex Nested Update Request

```javascript
// PATCH /deep_unrest/update
{
  redirect: '/api/submissions/123',
  data: [
    {
      path: 'submissions.123',
      attributes: { name: 'test' }
    },
    {
      path: "submissions.123.questions.456.answers.1",
      attributes: { value: 'yes' }
    },
    {
      path: "submissions.123.questions.456.answers[1]",
      attributes: {
        value: 'no',
        questionId: 456,
        submissionId: 123,
        applicantId: 890
      }
    },
    {
      path: "submissions.123.questions.456.answers.2",
      destroy: true
    }
  ]
}
```

### Example 5 - Bulk Updates
The following example will mark every `Submission` as `approved`.

When using an authorization strategy, the scope of the bulk update will be
limited to the current user's allowed scope.

#### Bulk Update Request

```javascript
// PATCH /deep_unrest/update
{
  redirect: '/api/submissions',
  data: [
    {
      path: 'submissions.*',
      attributes: {
        approved: true
      }
    }
  ]
}
```

### Example 6 - Bulk Delete
The following example will delete every submission.

When using an authorization strategy, the scope of the bulk delete will be
limited to the current user's allowed scope.

#### Bulk Delete Request

```javascript
// PATCH /deep_unrest/update
{
  redirect: '/api/submissions',
  data: [
    {
      path: 'submissions.*',
      destroy: true
    }
  ]
}
```

## TODO

* Allow the use of filters when performing bulk operations.
* How should we handle nested bulk operations? i.e. `submissions.*.questions.*.answers.*`

## Contributing
TDB

## License
The gem is available as open source under the terms of the [WTFPL](http://www.wtfpl.net/).
