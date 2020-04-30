module CloudModel
  module Workers
    module Components
      class RubyComponentWorker < BaseComponentWorker
        def build build_path
          # Ruby deps needed for most rails projects
          # TODO: Consider separating them to more Components
          packages = %w(ruby git)
          packages += %w(zlib1g-dev libxml2-dev) # Nokogiri
          packages << 'ruby-bcrypt' # bcrypt      
          packages << 'nodejs' # JS interpreter 
          packages << 'imagemagick' # imagemagick (TODO: needed for some rails projects, make this configurable)
          packages << 'libxml2-utils' # xmllint (TODO: needed for some rails projects, make this configurable)
          packages << 'libxslt-dev' # libxml (TODO: needed for some rails projects, make this configurable)
          chroot! build_path, "apt-get install #{packages * ' '} -y", "Failed to install packages for deployment of rails app"
          chroot! build_path, "gem install bundler", "Failed to install bundler"
        end
      end
    end
  end
end