module CloudModel

  # Handle IP resolution
  class AddressResolution
    require 'netaddr'

    include Mongoid::Document
    include Mongoid::Timestamps

    field :ip, type: String
    field :name, type: String
    field :active, type: Boolean, default: false
    field :ptr_active, type: Boolean, default: true

    before_validation :check_ip_format
    validates :ip, uniqueness: true
    validates :name, format: {with: /\A([\w-]+\.)*[\w\-]+\.\w{2,10}\z/}

    def self.for_subnet(subnet)
      subnet = CloudModel::Address.from_str subnet
      if subnet.ip_version == 4
        resolutions = []
        subnet.list_ips.each do |ip|
          resolutions << find_or_initialize_by(ip:ip)
        end
        resolutions
      else
        where(ip: /^#{subnet.ip.to_s}/)
      end
    end

    def address
      CloudModel::Address.from_str ip
    end

    def cidr
      address.cidr
    end

    private
    def check_ip_format
      if ip =~ /^[0-9a-f\.\:]+$/
        begin
          a = address
        rescue
          errors.add :ip, :invalid
        end
      else
        errors.add :ip, :invalid
      end
    end
  end
end