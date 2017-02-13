# Registration::Storage::InstallationOptions fake
class FakeInstallationOptions
  include Singleton
  attr_accessor :custom_url
end

# Registration::Storage::Config fake
class FakeRegConfig
  include Singleton
  def import(_args); end
end
