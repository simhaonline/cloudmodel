module CloudModel
  class Guest    
    require 'resolv'
    require 'securerandom'

    include Mongoid::Document
    include Mongoid::Timestamps
    
    include CloudModel::AcceptSizeStrings
    include CloudModel::ENumFields
    prepend CloudModel::SmartToString
  
    belongs_to :host, class_name: "CloudModel::Host"
    embeds_many :services, class_name: "CloudModel::Services::Base", :cascade_callbacks => true
    embeds_many :lxd_containers, class_name: "CloudModel::LxdContainer", :cascade_callbacks => true
    embeds_many :lxd_custom_volumes, class_name: "CloudModel::LxdCustomVolume", :cascade_callbacks => true
    field :current_lxd_container_id, type: BSON::ObjectId
    
    #has_many :guest_volumes, class_name: "CloudModel::GuestVolume"
    accepts_nested_attributes_for :lxd_custom_volumes, allow_destroy: true
    
    field :name, type: String
    
    field :private_address, type: String
    field :external_address, type: String
    field :mac_address, type: String
    field :external_alt_names, type: Array, default: []
    
    field :root_fs_size, type: Integer, default: 10737418240
    field :memory_size, type: Integer, default: 2147483648
    field :cpu_count, type: Integer, default: 2
    
    enum_field :deploy_state, values: {
      0x00 => :pending,
      0x01 => :running,
      0xf0 => :finished,
      0xf1 => :failed,
      0xff => :not_started
    }, default: :not_started
    
    field :deploy_last_issue, type: String
    field :deploy_path, type: String
    # attr_accessor :deploy_path
    #
    # def deploy_path
    #   @deploy_path ||= base_path
    # end
    #
    # def deploy_path=path
    #   @deploy_path = path
    # end
        
    accept_size_strings_for :memory_size
    
    has_many :guest_certificates, class_name: "CloudModel::GuestCertificate"

    validates :name, presence: true, uniqueness: { scope: :host }, format: {with: /\A[a-z0-9\-_]+\z/}
    validates :host, presence: true
    #validates :root_volume, presence: true
    validates :private_address, presence: true
    
    before_validation :set_dhcp_private_address, :on => :create
    before_validation :set_mac_address, :on => :create
    #before_validation :set_root_volume_name
    before_destroy    :undefine
    
    VM_STATES = {
      -1 => :undefined,
      0 => :no_state,
      1 => :running,
      2	=> :blocked,
      3 => :paused,
      4 => :shutdown,
      5 => :shutoff,
      6 => :crashed,
      7 => :suspended
    }
   
    def state_to_id state
      CloudModel::Livestatus::STATES.invert[state.to_sym] || -1
    end
    
    def vm_state_to_id state
      VM_STATES.invert[state.to_sym] || -1
    end
    
    def current_lxd_container
      lxd_containers.where(id: current_lxd_container_id).first
    end
    
    def base_path
      "/vm/#{name}"
    end
   
    def config_root_path
      "#{base_path}/etc"
    end

    def available_private_address_collection
      ([private_address] + host.available_private_address_collection - [nil])
    end
    
    def available_external_address_collection
      ([external_address] + host.available_external_address_collection - [nil])
    end
    
    def external_hostname
      @external_hostname ||= external_address.blank? ? '' : CloudModel::Address.from_str(external_address).hostname
    end
    
    def external_alt_names_string
      external_alt_names * ','
    end
    
    def external_alt_names_string=(string)
      self.external_alt_names = string.split(',').map &:strip
    end
    
    def uuid
      SecureRandom.uuid
    end
    
    def random_2_digit_hex
      "%02x" % SecureRandom.random_number(256)
    end
    
    def to_param
      name
    end
    
    def exec command
      host.exec "LANG=en.UTF-8 /usr/bin/virsh lxc-enter-namespace --noseclabel #{name.shellescape} -- #{command}"
    end
    
    def exec! command, message
      host.exec! "LANG=en.UTF-8 /usr/bin/virsh lxc-enter-namespace --noseclabel #{name.shellescape} -- #{command}", message
    end
    
    def ls directory
      res = exec("/bin/ls -l #{directory.shellescape}")
      
      pp res
      
      if res[0]
        res[1].split("\n")
      else
        puts res[1]
        false
      end
    end
    
    def certificates
      ids = guest_certificates.pluck(:certificate_id)
      services.each do |service|
        ids << service.ssl_cert_id if service.respond_to?(:ssl_cert_id) and service.ssl_cert_id
      end
      
      CloudModel::Certificate.where(:id.in => ids)
    end
    
    def has_certificates?
      certificates.count > 0
    end
    
    def has_service?(service_type)
      services.select{|s| s._type == service_type}.count > 0
    end
    
    def components_needed
      components = []
      services.each do |service|
        components += service.components_needed
      end
      
      components.uniq.sort{|a,b| a<=>b}
    end
    
    def template_type
      CloudModel::GuestTemplateType.find_or_create_by components: components_needed
    end
    
    def template
      template_type.last_useable(host)
    end
    
    def shinken_services_append
      services_string = ''
      
      services.each do |service|
        if service_string = service.shinken_services_append
          services_string += service_string
        end
      end
      
      services_string
    end
    
    def worker
      CloudModel::GuestWorker.new self
    end
    
    def self.deploy_state_id_for deploy_state
      enum_fields[:deploy_state][:values].invert[deploy_state]
    end
    
    def self.deployable_deploy_states
      [:finished, :failed, :not_started]
    end
    
    def self.deployable_deploy_state_ids
      deployable_deploy_states.map{|s| deploy_state_id_for s}
    end
    
    def deployable?
      self.class.deployable_deploy_states.include? deploy_state
    end
    
    def self.deployable?
      where :deploy_state_id.in => deployable_deploy_state_ids
    end
    
    def deploy(options = {})
      unless deployable? or options[:force]
        return false
      end
      
      update_attribute :deploy_state, :pending
      
      begin
        CloudModel::call_rake 'cloudmodel:guest:deploy', host_id: host_id, guest_id: id
      rescue Exception => e
        update_attributes deploy_state: :failed, deploy_last_issue: 'Unable to enqueue job! Try again later.'
        CloudModel.log_exception e
      end
    end
    
    def deploy!(options={})
      guest_worker = CloudModel::GuestWorker.new self
      guest_worker.deploy options
    end
    
    def redeploy(options = {})
      unless deployable? or options[:force]
        return false
      end
      
      update_attribute :deploy_state, :pending
      
      begin
        CloudModel::call_rake 'cloudmodel:guest:redeploy', host_id: host_id, guest_id: id
      rescue Exception => e
        update_attributes deploy_state: :failed, deploy_last_issue: 'Unable to enqueue job! Try again later.'
        CloudModel.log_exception e
      end
    end
  
    def redeploy!(options={})
      guest_worker = CloudModel::GuestWorker.new self
      guest_worker.redeploy options
    end
    
    def self.redeploy(ids, options = {})
      criteria = self.where(:id.in => ids.map(&:to_s))      
      valid_ids = criteria.pluck(:_id).map(&:to_s)
      
      return false if valid_ids.empty? and not options[:force]
      
      criteria.update_all deploy_state_id: deploy_state_id_for(:pending)
      
      begin
        CloudModel::call_rake 'cloudmodel:guest:redeploy_many', guest_ids: valid_ids * ' '
      rescue Exception => e
        criteria.update_all deploy_state_id: deploy_state_id_for(:failed), deploy_last_issue: 'Unable to enqueue job! Try again later.'
        CloudModel.log_exception e
      end
    end
    
    def livestatus
      @livestatus ||= CloudModel::Livestatus::Host.find("#{host.name}.#{name}", only: %w(host_name description state plugin_output perf_data))
    end
    
    def state
      if livestatus
        livestatus.state
      else
        -1
      end
    end
    
    def vm_state
      @real_state unless @real_state.blank?
      begin
        @real_state = vm_state_to_id virsh('domstate').strip
      rescue
        -1
      end
    end
    
    def vm_info
      @real_vm_info unless @real_vm_info.blank?
      begin
        vm_info={}
        res = virsh('dominfo')
    
        res.lines.each do |line|
          k,v = line.split(':')
          vm_info[k.gsub(' ', '_').underscore] = v.try(:strip)
        end
    
        vm_info['memory']  = vm_info.delete('used_memory').to_i * 1024
        vm_info['max_mem'] = vm_info.delete('max_memory').to_i * 1024
        vm_info['state']   = vm_state_to_id(vm_info['state'])
        vm_info['cpus']    = vm_info.delete("cpu(s)").to_i
        vm_info['active']  = (vm_info['state'] == 1)
        
        vm_info
      rescue
        {"state" => -1}
      end
    end
    
    def start(lxd_container = nil)
      unless lxd_container.blank?
        lxd_container_id = if lxd_container.is_a? CloudModel::LxdContainer
          lxd_container.id
        else
          lxd_container
        end
        collection.update_one({_id:  id}, '$set' => { 'current_lxd_container_id': lxd_container_id })
        self.current_lxd_container_id = lxd_container_id
        #self.write_attribute database_field_name(:current_lxd_container_id), lxd_container_id
        #save
      end
      
      begin
        return current_lxd_container.start
      rescue
        return false
      end
    end
    
    def stop
      begin
        lxd_containers.each do |c|
          c.stop if c.running?
        end
      rescue
        return false
      end
    end
    
    def stop! options = {}
      stop
      timeout = options[:timeout] || 600
      while vm_state != -1 and timeout > 0 do
        sleep 0.1
        timeout -= 1
      end
    end
    
    def undefine
      begin
        # Return true if the domain is not defined before
        if VM_STATES[vm_state] == :undefined
          Rails.logger.debug "Domain #{self.name} was not defined before"
          return true
        end
        
        # If not started shutdown will fail, but if it fails the undefine will fail anyway
        stop!
        return virsh('undefine')
      rescue
        return false
      end
    end
    
    def backup
      success = true
      
      # guest_volumes.where(has_backups: true).each do |volume|
      #   Rails.logger.debug "V #{volume.mount_point}: #{success &&= volume.backup}"
      # end

      services.where(has_backups: true).each do |service|
        Rails.logger.debug "S #{service._type}: #{success &&= service.backup}" 
      end      
      
      success
    end
    
    def generate_mac_address
      def format_mac_address_postfix(i)
        "00:16:3e:#{host.mac_address_prefix}:#{i.to_s(16).rjust(2,'0').upcase}"
      end
      
      i=1      
      while(i<2**8 and host.guests.where(mac_address: format_mac_address_postfix(i), :_id.ne => id).count > 0)
        i += 1
      end

      self.mac_address = format_mac_address_postfix(i)
    end
    
    private  
    def set_dhcp_private_address
      self.private_address = host.dhcp_private_address if private_address.blank?
    end
    
    def set_mac_address
      generate_mac_address if mac_address.blank?
    end
    
    # def set_root_volume_name
    #   root_volume.name = "#{name}-root-#{Time.now.strftime "%Y%m%d%H%M%S"}" unless root_volume.name
    #   root_volume.volume_group = host.volume_groups.first unless root_volume.volume_group
    # end
  end
end
