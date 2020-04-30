module CloudModel
  class Config 
    attr_writer :data_directory, :backup_directory, :bundle_command
    attr_writer :skip_sync_images
    # Use external IP, useful for testing without setting up a VPN for your development box or if you have troubles woith tinc
    attr_writer :use_external_ip
    attr_writer :dns_servers
    
    attr_writer :ubuntu_mirror, :ubuntu_deb_src, :ubuntu_version, :ubuntu_name
    
    attr_accessor :admin_email, :email_domain
     
    attr_writer :host_mac_address_prefix_init

    attr_accessor :monitoring_notifiers
    
    def initialize(&block) 
      configure(&block) if block_given?
    end

    # Configure your CloudModel Rails Application with the given parameters in 
    # the block. For possible options see above.
    def configure(&block)
      yield(self)
    end
    
    def data_directory
      @data_directory || "#{Rails.root}/data"
    end
    
    def backup_directory
      @backup_directory || "#{data_directory}/backups"
    end
    
    def bundle_command
      @bundle_command || 'PATH=/usr/local/bin:/bin:/sbin:/usr/bin bundle'
    end
    
    # If true do not sync images on deploy
    def skip_sync_images
      @skip_sync_images || false
    end
    
    def use_external_ip
      @use_external_ip || false
    end
    
    def dns_servers
      @dns_servers || %w(1.1.1.1 8.8.8.8 9.9.9.10)
    end
        
    def ubuntu_mirror
      @ubuntu_mirror || 'http://archive.ubuntu.com/ubuntu/'
    end
    
    def ubuntu_deb_src
      if @ubuntu_deb_src.nil?
        true
      else
        @ubuntu_deb_src 
      end
    end
    
    def ubuntu_version 
      @ubuntu_version || "18.04"
    end
    
    def ubuntu_name
      @ubuntu_name || "Bionic Beaver"
    end
    
    def host_mac_address_prefix_init
      @host_mac_address_prefix_init || '00:00'
    end
    
    def monitoring_notifiers
      @monitoring_notifiers || []
    end
  end
end