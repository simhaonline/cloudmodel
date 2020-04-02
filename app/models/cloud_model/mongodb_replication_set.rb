module CloudModel
  class MongodbReplicationSet
    include Mongoid::Document
    include Mongoid::Timestamps
    include CloudModel::Mixins::HasIssues
    prepend CloudModel::Mixins::SmartToString
    
    field :name, type: String # Name of the replication set

    def services
      CloudModel::Guest.where("services.mongodb_replication_set_id" => id).map{ |guest| 
        guest.services.where(mongodb_replication_set_id: id).to_a
      }.flatten   
    end
    
    def add_service service
      service.update_attribute :mongodb_replication_set_id, id
    end
    
    def init_rs_cmd
      cmd = "rs.initiate( {\n" + 
            "   _id : \"#{name}\",\n" +
            "   members: [\n"

      services.each_with_index do |service,i|
        cmd += "      { _id: #{i}, host: \"#{service.private_address}:#{service.port}\" },\n"
      end
      
      cmd += "   ]\n" +
             "})\n"
             
      puts cmd
    end
  end
end