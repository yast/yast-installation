# Modifying the Installation by an Add-on

The YaST installation workflow can be easily changed or extended by add-ons.


## Configuring the Add-on Metadata

The product package on the add-on medium (usually a `*-release` RPM package)
should link to a package providing the installer extension by a
`Provides: installerextension(<package_name>)` dependency.

That referenced package should contain the `installation.xml` file and optionally
the `y2update.tgz` archive.

## Modifying the Installation Defaults

### Adding a New System Role

This `installation.xml` example adds a new role:

```xml
<?xml version="1.0"?>
<!DOCTYPE productDefines SYSTEM "/usr/share/YaST2/control/control.rng">
<productDefines xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
    <!-- defines the gettext domain for the messages in this XML -->
    <textdomain>testing-extension-control</textdomain>

    <update>
        <system_roles>
          <insert_system_roles config:type="list">
            <insert_system_role>
              <system_roles config:type="list">
                <system_role>
                  <id>mail_role</id>
                  <software>
                    <default_patterns>base Minimal mail_server</default_patterns>
                  </software>
                </system_role>
              </system_roles>
            </insert_system_role>
          </insert_system_roles>
        </system_roles>
    </update>

    <!-- Don't forget to add the texts -->
    <texts>
      <mail_role>
        <label>Testing Extension Role</label>
      </mail_role>
      <mail_role_description>
        <label>• Mail server software pattern
• This is just an example!</label>
      </mail_role_description>
    </texts>
</productDefines>
```

In this case it just configures the default software patterns but it is possible
to define any other defaults like partitioning, firewall status, etc...

## Adding New YaST Code

The installer extension package can optionally contain `y2update.tgz` archive
with executable YaST code in the usual directory structure. E.g. the clients are
read from the `/usr/share/YaST2/clients` directory in the archive.

### YaST Client Example

Here is a trivial example client which just displays a pop up dialog with a message:

```ruby
module Yast
  class TestingExtensionClient < Client
    include Yast::I18n

    def initialize
      textdomain "testing-extension"
      Yast.import("Popup")
    end

    def main
      # TRANSLATORS: A popup message
      Popup.Message(_("This is an inserted step from the testing-extension addon."\
        "\n\nPress OK to continue."))
      return :auto
    end
  end
end

Yast::TestingExtensionClient.new.main
```

Save this file to `usr/share/YaST2/clients/inst_testing_extension.rb` file (including
the directory structure) and then create the `y2update.tgz` archive with command

```
tar cfzv y2update.tgz usr
```

and include this file in the installer extension RPM package.

# An Example Add-on

A minimalistic but complete example add-on can be found in the [YaST:extension](
https://build.opensuse.org/project/show/YaST:extension) OBS project.
