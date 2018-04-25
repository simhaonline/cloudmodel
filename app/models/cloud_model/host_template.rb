module CloudModel  
  class HostTemplate
    include Mongoid::Document
    include Mongoid::Timestamps
    include CloudModel::ENumFields
        
    field :os_version
    field :arch
    
    has_many :templates, class_name: "CloudModel::GuestTemplate"
        
    enum_field :build_state, values: {
      0x00 => :pending,
      0x01 => :running,
      0x05 => :packaging,
      0x10 => :downloading,
      0xf0 => :finished,
      0xf1 => :failed,
      0xff => :not_started
    }, default: :not_started

    field :build_last_issue
  
    def self.buildable_build_states
      [:finished, :failed, :not_started]
    end
    
    def buildable?
      self.class.buildable_build_states.include? build_state
    end
    
    def self.new_template_to_build host
      CloudModel::HostTemplate.create arch: host.arch
    end
    
    def self.build!(host, options={})
      template = new_template_to_build(host)
      template.build_state = :pending
      template.build! host, options
    end
    
    def build(host, options = {})
      unless buildable? or options[:force]
        return false
      end

      update_attributes build_state: :pending, arch: host.arch

      begin
        CloudModel::call_rake 'cloudmodel:host_template:build', host_id: host.id, template_id: id
      rescue Exception => e
        template.update_attributes build_state: :failed, build_last_issue: 'Unable to enqueue job! Try again later.'
        CloudModel.log_exception e
      end
    end
    
    def worker host
      CloudModel::HostTemplateWorker.new host
    end
  
    def build!(host, options={})
      worker(host).build_template self, options
    end  
    
    def self.last_useable(host, options={})
      template = self.where(arch: host.arch, build_state_id: 0xf0).last
      unless template
        template = new_template_to_build host
        template.build_state = :pending
        template.build!(host, options)
      end
      template
    end
    
    def tarball
      "/cloud/templates/host/#{id}.tar.gz"
    end
  end
end