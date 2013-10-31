Installation Features
=====================

This section contains description of several installation features.

Additional Products Automatically Added with Installation Repository
--------------------------------------------------------------------

You can easily add several additional products automatically just by
using a modified installation repository or media.

During installation or upgrade from media (CD, DVD, HTTP server, ...)
installation adds a primary installation repository, this repository can
contain special configuration file with list of additional repositories
that would be automatically added by YaST.

The configuration is written in XML - which means extending the format
(adding new features) is easier comparing to the old plain-file format.

### Configuration file *add\_on\_products.xml*

File *add\_on\_products.xml* is placed in the media root.

Commented example:

```
<?xml version="1.0"?>
<add_on_products xmlns="http://www.suse.com/1.0/yast2ns"
	xmlns:config="http://www.suse.com/1.0/configns">
	<!-- List of available products -->
	<product_items config:type="list">

		<!-- The first product item -->
		<product_item>
			<!-- Product name visible in UI when offered to user (optional item) -->
			<name>Add-on Name to Display</name>
			<!-- Product URL (mandatory item) -->
			<url>http://product.repository/url/</url>
			<!-- Product path, default is "/" (optional item) -->
			<path>/relative/product/path</path>
			<!--
				List of products to install from media, by default all products
				from media are installed (optional item)
			-->
			<install_products config:type="list">
				<!--
					Product to install - matching the metadata product 'name'
					(mandatory to fully define 'install_products')
				-->
				<product>Product-ID-From-Repository</product>
				<product>...</product>
			</install_products>
			<!--
				If set to 'true', user is asked whether to install this product,
				default is 'false' (optional)
			-->
			<ask_user config:type="boolean">true</ask_user>
			<!--
				Connected to 'ask_user', sets the default status of product,
				default is 'false' (optional)
			-->
			<selected config:type="boolean">true</selected>
		</product_item>

		<!-- Another product item -->
		<product_item />
	</product_items>
</add_on_products>
```

-   (string) *url* - repository URL; absolute or relative to the base
    installation repository; relative URL is useful when the same
    repository is used via several access methods (e.g., NFS+HTTP+FTP).

    Absolute:

        <url>http://example.com/SUSE_5.0/<url>

    Relative:

        <url>../SUSE_5.0/<url>

-   (string) *name* - Product name used when repositories are offered to
    user in UI before adding them, see *ask\_user* for more; if not set,
    product URL and/or other items are used instead.

-   (string) *path* - Additional product path in the repository, useful
    when there are more product at one URL; the default is */* if not
    set.

-   (boolean) *ask\_user* - Users are asked whether to add such a
    product; products without this parameter are added automatically;
    default is *false*

-   (boolean) *selected* - Defines the default state of *pre-selected*
    state in case of *ask\_user* used; default is *false*

-   (list \<string\>) *install\_products/product* - List of products to
    add if there are more than one products at the repository URL; if
    not defined, all products are installed.

### Configuration file *add\_on\_products*

File *add\_on\_products* is an obsolete format of
*[add\_on\_products.xml](#installation_features_add_on_products.xml)*
described above. It does not have additional features of the newer
format and it is almost impossible to extend it.

Repositories listed in this file are added automatically with the
primary installation repository.

Example:

```
http://some.product.repository/url1/
http://some/product.repository/url2/	/relative/product/path
http://some.product.repository/url3/	/	Product-1 Product-2
```

Repository entries are newline-separated, repository items are
white-space-separated (*tab* or *space*).

-   First item: (string) *url* - repository URL; absolute or relative to
    the base installation repository; relative URL is useful when the
    same repository is used via several access methods (e.g.,
    NFS+HTTP+FTP).

    Absolute:

        <url>http://example.com/SUSE_5.0/<url>

    Relative:

        <url>../SUSE_5.0/<url>

-   Second item: (string) *path* - Additional product path in the
    repository, useful when there are more product at one URL; the
    default is */* if not set.

-   Third .. *n* item: (string) ** - products to add if there are more
    than one products at the repository URL; if not defined, all
    products are installed.


