module CloudModel
  class RedisSentinelSet
    include Mongoid::Document
    include Mongoid::Timestamps
    
    field :name, type: String
    belongs_to :master_service, class_name: "CloudModel::Services::Redis"

    def services
      CloudModel::Guest.where("services.redis_sentinel_set_id" => id).map{ |guest| 
        guest.services.where("redis_sentinel_set_id" => id).to_a
      }.flatten   
    end
    
    def add_service service
      service.update_attributes redis_sentinel_set_id: id
    end
    
    def master_service
      if master_service_id
        CloudModel::Services::Base.find(master_service_id)
      else
        services.first
      end
    end
    
    def master_address
      master_service.guest.private_address
    end
    
    def master_node
      master_service.guest
    end
    
    def sentinel_hosts
      services.map do |s| 
        {'ip' => s.guest.private_address, 'port' => s.redis_sentinel_port}
      end
    end
  end
end