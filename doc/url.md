# URL handling in the installer

For a general description of URL formats see [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986#section-3).

## Absolute URLs

There are a number of places where URLs are processed in the installer. But
all can be traced to one of three backends:

1. [Linuxrc](https://en.opensuse.org/SDB:Linuxrc#Parameter_Reference)
2. [Zypp](https://doc.opensuse.org/projects/libzypp/HEAD/classzypp_1_1media_1_1MediaManager.html#MediaAccessUrl)
3. [YaST/AutoYaST](https://doc.opensuse.org/projects/autoyast/#Commandline-ay) itself in [Yast::Transfer::FileFromUrl.get_file_from_url](https://github.com/yast/yast-installation/blob/b950b062729d98d11d98609cba829bbc39355143/src/lib/transfer/file_from_url.rb#L76-L92)

> There was additionally a 4th one hidden in AutoYaST:
> 
> 4. [Yast::ProfileLocationClass.Process](https://github.com/yast/yast-autoinstallation/blob/SLE-15-SP4/src/modules/ProfileLocation.rb#L101-L116)
>   took care of the `label` scheme in AutoYaST context. It's been added to `Yast::Transfer::FileFromUrl` now.

## Relative URLs

On top of the above three locations there is special handling for `relurl`
and `repo` URLs throughout the Linuxrc and YaST code - mostly concerned constructing the absolute URL.

`relurl` is a relative URL where the location it is relative to varies on
context. It can be relative to the installation repository, relative to the
AutoYaST profile, or relative to the main product in the context of add-on
or product descriptions.

`repo` is a URL that is always relative to the installation repository.

## URL formats

All three backends have a collection of their own URL formats. Not so much for
standardized URL schemes as `http` or `ftp` - but schemes referring to local
media vary.

Some standarization attempts have been made in the past. As a result Linuxrc
supports also Zypp and (Auto)YaST formats. Note that Linuxrc always uses the Zypp format
when passing URLs to YaST in `install.inf`.

`FileFromUrl` has been extended in SLE15-SP5 to work also with Zypp formats. The
rationale is that extending Zypp is out of scope for YaST and we have no
control over the URL parsing there. So consolidating on Zypp syntax seems
the best approach.

## URL format reference

This is a brief overview with examples. For a full reference, see the documentation links provided above.

### Linuxrc

- network URLs: `ftp`, `http`, `https`, `tftp`, `nfs`, `cifs`, `smb` - with usual syntax
- `slp:/`, `slp:/?descr=*openSUSE*&url=ftp:*`
- `file:/foo`, `file:///foo`, (`file://foo` also works)
- `cd:/`, `cd:/?device=/dev/sr0`
- `hd:/foo`, `hd:/foo?device=/dev/sda`, `hd:/foo.iso`
- `disk:/foo`, `disk:/foo?device=/dev/sda` - `disk` can mean either CDROM or hard disk
- `rel:/foo`, `rel:///foo`
- `relurl://foo`
- `repo:/foo`, `repo:///foo`

### (Auto)YaST via FileFromUrl

- network URLs: `ftp`, `http`, `https`, `tftp`, `nfs`, `cifs` - with usual syntax (note: **not** `smb`)
- `file:/foo`, `file:///foo`, (`file://foo` also works)
- `device://sda/foo`, `device://disk/by-id/some_id/foo`
- `hd:/foo?device=/dev/sda`
- `cd:/?devices=/dev/sr0`
- `dvd:/?devices=/dev/sr0`
- `usb:///foo`
- `label://some_label/foo`
- `relurl://foo`
- `repo:/foo`, `repo:///foo`

Note that `file` looks on the local file system **and** installation medium for the file.

### Zypp

- network URLs: `ftp`, `http`, `https`, `tftp`, `nfs`, `cifs`, `smb` - with usual syntax
- `file:/foo`, `file:///foo`
- `dir:/foo`, `dir:///foo`
- `hd:/foo?device=/dev/sda`
- `cd:/?devices=/dev/sr0`
- `dvd:/?devices=/dev/sr0`
- `iso:/?iso=/foo.iso&url=hd:/?device=/dev/sda`

## Going forward

There are still issues with the existing URL handling in YaST. I'll present
code examples to illustrate the point. Note that this is not meant as picking at the code in any way.

### 1. Wrong number of slashes

The [description](https://doc.opensuse.org/projects/autoyast/#Commandline-ay) of some URL schemes (e.g. `relurl` - and historically `file`
had been documented this way)
demand the URL to start with two slashes (`//`) - which is not what one would expect according to the URI RFC cited at the beginning.

This leads to all kinds of issues when processing URLs as the real path has
to be reconstructed by merging the hostname component and the path fragment you get after parsing the URL.

Typically something like [this](https://github.com/yast/yast-autoinstallation/blob/695bc29ac79dae970dae63da55b624ec03a04e16/src/modules/AutoinstConfig.rb#L364-L379):

```ruby
if @scheme == "relurl" || @scheme == "file"
  # "relurl": No host information has been given here. So a part of the path or the
  # complete path has been stored in the host variable while parsing it.
  # This will be reverted.
  #
  # "file": Normally the file is defined with 3 slashes like file:///autoinst.xml
  # in order to define an empty host entry. But that will be often overseen
  # by the user. So we will support file://autoinst.xml too:
  log.info "correcting #{@scheme}://#{@host}/#{@filepath} to empty host entry"
  if !@host.empty? && !@filepath.empty?
    @filepath = File.join(@host, @filepath)
  else
    @filepath = @host unless @host.empty?
  end
  @host = ""
end
```

Note that the existing code will tolerate using one or three slashes even
when only two are documented in most cases. `file` should be fairly safe,
for example. `relurl` not always, though. The next section has an example
where the code is not forgiving.

It's probably not a good idea to change the documentation at this point but
maybe we should tolerate differing number of slashes in some cases.
 
### 2. Regexp parsing of URLs

For example this (https://github.com/yast/yast-packager/blob/SLE-15-SP4/src/modules/AddOnProduct.rb#L409-L412):

```ruby
if !Builtins.regexpmatch(url, "^relurl://")
  Builtins.y2debug("Not a relative URL: %1", URL.HidePassword(url))
  return url
end
```

There are often hidden assumptions in these regexps (e.g. that `relurl` starts with at least two slashes)
that might break things at some point.

But there is a perfectly fine [URI](https://docs.ruby-lang.org/en/master/URI.html) class
in ruby that can do this better. For example:

```ruby
if URI(url).scheme != "relurl"
  ...
end
```

And there is also the
[Yast::URLClass](https://github.com/yast/yast-yast2/blob/master/library/types/src/modules/URL.rb)
class for handling URLs. On the negative side this is old YCP code but on the
positive side it deals with idiosyncrasies like varying number of slashes.

### 3. Manually converting relative URLs to absolute URLs

The conversion of relative to absolute URLs has been programmed several times. For example [here](https://github.com/yast/yast-autoinstallation/blob/695bc29ac79dae970dae63da55b624ec03a04e16/src/lib/autoinstall/script.rb#L149-L168):

```ruby
def resolve_location
  return if location.empty?

  log.info "Resolving location #{location.inspect}"
  location.strip!
  return unless location.start_with?("relurl://")

  path = location[9..-1] # 9 is relurl:// size

  if Yast::AutoinstConfig.scheme == "relurl"
    log.info "autoyast profile was relurl too"
    newloc = Yast::SCR.Read(Yast::Path.new(".etc.install_inf.ayrelurl"))
    tok = Yast::URL.Parse(newloc)
    @location = "#{tok["scheme"]}://#{File.join(tok["host"], File.dirname(tok["path"]), path)}"
  else
    config = Yast::AutoinstConfig
    @location = "#{config.scheme}://#{File.join(config.host, config.directory, path)}"
  end
  log.info "resolved location #{@location.inspect}"
end
```

There is a [Yast2::RelURL](https://github.com/yast/yast-yast2/blob/master/library/general/src/lib/yast2/rel_url.rb) class that can do exactly that.

```ruby
Yast2::RelURL.new("http://example.com", "relurl://foo/bar").absolute_url.to_s
# "http://example.com/foo/bar"

```

### 4. URLs (absolute and relative) referring to the installation ISO

You can use the unpacked installation ISO as installation source. For example:

```
  hd:/foo/tw.iso?device=/dev/sda                    # Linuxrc syntax
  iso:/?iso=/foo/tw.iso&url=hd:/?device=/dev/sda"   # Zypp syntax
  -- unsupported --                                 # (Auto)YaST syntax
```

`FileFromUrl` does not support this. This means you cannot reference an
AutoYaST profile this way. Neither directly nor indirectly via `relurl` or
`repo`.

It is in fact an interesting question what you would want
`autoyast=repo:/bar.xml` to mean in this context. Maybe not that `bar.xml`
is inside the ISO alongside the repository but **outside** alongside the ISO. That is,
`autoyast=hd:/foo/bar.xml` - which would also be more easily implemented, btw.
