# This component patches the pl-ruby package on cross compiled
# platforms. Ruby gem components should require this.
#
# We have to do this when installing gems with native extensions in
# order to trick rubygems into thinking we have a different ruby
# version and target architecture
#
# This component should also be present in the puppet-runtime project
component "pl-ruby-patch" do |pkg, settings, platform|
  if platform.is_cross_compiled?
    if platform.is_macos?
      pkg.build_requires 'gnu-sed'
      pkg.environment "PATH", "/usr/local/opt/gnu-sed/libexec/gnubin:$(PATH)"
    end

    ruby_api_version = settings[:ruby_version].gsub(/\.\d*$/, '.0')
    ruby_version_y = settings[:ruby_version].gsub(/(\d+)\.(\d+)\.(\d+)/, '\1.\2')

    base_ruby = case platform.name
                when /solaris-10/
                  "/opt/csw/lib/ruby/2.0.0"
                when /osx/
                  "/usr/local/opt/ruby@#{ruby_version_y}/lib/ruby/#{ruby_api_version}"
                else
                  "/opt/pl-build-tools/lib/ruby/2.1.0"
                end

    # weird architecture naming conventions...
    unless platform.name =~ /solaris-10/
      target_triple = if platform.architecture =~ /ppc64el|ppc64le/
                        "powerpc64le-linux"
                      elsif platform.name == 'solaris-11-sparc'
                        "sparc-solaris-2.11"
                      elsif platform.is_macos?
                        "aarch64-darwin"
                      else
                        "#{platform.architecture}-linux"
                      end

      pkg.build do
        [
          %(#{platform[:sed]} -i 's/Gem::Platform.local.to_s/"#{target_triple}"/' #{base_ruby}/rubygems/basic_specification.rb),
          %(#{platform[:sed]} -i 's/Gem.extension_api_version/"#{ruby_api_version}"/' #{base_ruby}/rubygems/basic_specification.rb)
        ]
      end
    end

    # make rubygems use our target rbconfig when installing gems
    if ruby_version_y == '2.7'
      sed_command = %(s|Gem.ruby.shellsplit|& << '-r/opt/puppetlabs/puppet/share/doc/rbconfig-#{settings[:ruby_version]}-orig.rb'|)
    else
      sed_command = %(s|Gem.ruby|&, '-r/opt/puppetlabs/puppet/share/doc/rbconfig-#{settings[:ruby_version]}-orig.rb'|)
    end

    pkg.build do
      [
        %(#{platform[:sed]} -i "#{sed_command}" #{base_ruby}/rubygems/ext/ext_conf_builder.rb)
      ]
    end
  end
end
