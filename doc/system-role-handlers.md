# System Role Handlers

This is a mechanism that allows to execute specific code depending on the system
role selected during the installation which was introduced in version 3.2.21
(originally in 3.1.217.20 in the `SLE-12-SP2-CASP` branch).

If you prefer, you could think of them as *hooks for system roles*.

## Types of handlers

Currently only one type of handlers exist: `finish`. Those handlers will be
executed through the
[roles_finish](https://github.com/yast/yast-installation/blob/master/src/lib/installation/clients/roles_finish.rb)

## Defining a new handler

Handlers are just plain classes which implement a `run` method and live in the
`lib/y2system_role_handlers`. The name of the file/class depends on the type of
handler they implement.

For instance, if you want to define a *finish* handler for an *ExampleRole* role,
just drop a file like this into `lib/y2system_role_handlers`.

```ruby
module Y2SystemRoleHandlers
  class ExampleRoleFinish
    def run
      # Handler implementation goes here
    end
  end
end

```

The `run` method won't receive any argument and is also not expected to return
any special value. Finally, exceptions will be handled like any other YaST
exception.

## Examples

Please, check out the [yast2-caasp package](https://github.com/yast/yast-caasp)
for examples.
