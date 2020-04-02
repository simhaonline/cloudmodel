# encoding: UTF-8

require 'spec_helper'

describe CloudModel::Guest do
  it { expect(subject).to have_timestamps }  

  it { expect(subject).to belong_to(:host).of_type CloudModel::Host }
  it { expect(subject).to embed_many(:services).of_type CloudModel::Services::Base }
  it { expect(subject).to embed_many(:lxd_containers).of_type CloudModel::LxdContainer }
  it { expect(subject).to embed_many(:lxd_custom_volumes).of_type CloudModel::LxdCustomVolume }
  it { expect(subject).to have_field(:current_lxd_container_id).of_type BSON::ObjectId }
  it { expect(subject).to have_many(:guest_certificates).of_type CloudModel::GuestCertificate}
  
  it { expect(subject).to have_field(:name).of_type String }
  
  it { expect(subject).to have_field(:private_address).of_type String }
  it { expect(subject).to have_field(:external_address).of_type String }
  it { expect(subject).to have_field(:mac_address).of_type String }
  it { expect(subject).to have_field(:external_alt_names).of_type(Array).with_default_value_of [] }

  it { expect(subject).to have_field(:root_fs_size).of_type(Integer).with_default_value_of 10*1024*1024*1024 }
  it { expect(subject).to have_field(:memory_size).of_type(Integer).with_default_value_of 2*1024*1024*1024 }
  it { expect(subject).to have_field(:cpu_count).of_type(Integer).with_default_value_of 2 }

  it { expect(subject).to have_enum(:deploy_state).with_values(
    0x00 => :pending,
    0x01 => :running,
    0xf0 => :finished,
    0xf1 => :failed,
    0xff => :not_started
  ).with_default_value_of(:not_started) }
  
  it{ expect(subject).to have_field(:deploy_last_issue).of_type String }
  it{ expect(subject).to have_field(:deploy_path).of_type String }

  it { expect(subject).to validate_presence_of(:name) }
  it { expect(subject).to validate_uniqueness_of(:name).scoped_to(:host) }
  it { expect(subject).to validate_format_of(:name).to_allow("host-name-01") }
  it { expect(subject).to validate_format_of(:name).not_to_allow("Test Host") }
  
  it { expect(subject).to validate_presence_of(:host) }
  it { expect(subject).to validate_presence_of(:private_address) }
  
  let(:host) { Factory.build :host }
  
  context 'root_fs_size=' do
    it 'should parse input as size string' do
      expect(subject).to receive(:accept_size_string_parser).with('Size String').and_return(23)
      subject.root_fs_size = 'Size String'
      
      expect(subject.root_fs_size).to eq 23
    end
  end
  
  context 'memory_size=' do
    it 'should parse input as size string' do
      expect(subject).to receive(:accept_size_string_parser).with('Size String').and_return(42)
      subject.memory_size = 'Size String'
      
      expect(subject.memory_size).to eq 42
    end
  end
  
  context 'current_lxd_container' do
    it 'should get lxd_container with current_lxd_container_id' do
      container = double CloudModel::LxdContainer
      current_container_id = BSON::ObjectId.new
      subject.current_lxd_container_id = current_container_id
      expect(subject.lxd_containers).to receive(:where).with(id: current_container_id).and_return [container]
      
      expect(subject.current_lxd_container).to eq container
    end
  end
  
  context 'available_private_address_collection' do
    it 'should return host´s available_private_address_collection and add it´s own private address' do
      subject.host = host
      expect(host).to receive(:available_private_address_collection).and_return(['10.42.42.4', '10.42.42.6'])
      subject.private_address = '10.42.42.12'
      expect(subject.available_private_address_collection).to eq [
        '10.42.42.12',
        '10.42.42.4',
        '10.42.42.6'
      ]
    end
  end
  
  context 'available_external_address_collection' do
    it 'should return host´s available_external_address_collection and add it´s own external address' do
      subject.host = host
      expect(host).to receive(:available_external_address_collection).and_return(['192.168.42.4', '192.168.42.6'])
      subject.external_address = '192.168.42.12'
      expect(subject.available_external_address_collection).to eq [
        '192.168.42.12',
        '192.168.42.4',
        '192.168.42.6'
      ]
    end
  end
  
  context 'external_hostname' do
    it 'should lookup the hostname for the external ip' do
      allow(Resolv).to receive(:getname).with('127.0.0.1').and_return('localhost')
      subject.external_address = '127.0.0.1'
      expect(subject.external_hostname).to eq 'localhost'
    end
    
    it 'should return the raw ip if lookup fails' do
      allow(Resolv).to receive(:getname).with('127.0.0.1').and_raise('DNS not available')
      subject.external_address = '127.0.0.1'
      expect(subject.external_hostname).to eq '127.0.0.1'
    end
  end
  
  context 'external_hostname' do
    it 'should return blank string if no external address' do
      expect(subject.external_hostname).to eq ''
    end
    
    it 'should get hostname for external address via Address' do
      address = double CloudModel::Address
      allow(CloudModel::Address).to receive(:from_str).with('198.51.100.42').and_return address
      allow(address).to receive(:hostname).and_return 'myhost.example.com'
      
      subject.external_address = '198.51.100.42'
      expect(subject.external_hostname).to eq 'myhost.example.com'
    end
  end
  
  context 'external_alt_names_string' do
    it 'should concat alt_names with a comma' do
      allow(subject).to receive(:external_alt_names).and_return ['alt.example.com', 'www.alt.example.com']
      
      expect(subject.external_alt_names_string).to eq "alt.example.com,www.alt.example.com"
    end
  end
  
  context 'external_alt_names_string=' do
    it 'should allow to set alt_names with comma separated string' do
      subject.external_alt_names_string = "alt.example.com,www.alt.example.com"
      
      expect(subject.external_alt_names).to eq ['alt.example.com', 'www.alt.example.com']
    end
    
    it 'should allow spaces in comma separated string' do
      subject.external_alt_names_string = "alt.example.com, www.alt.example.com"
      
      expect(subject.external_alt_names).to eq ['alt.example.com', 'www.alt.example.com']
    end
  end
  
  context 'uuid' do
    it 'creates a secure random UUID' do
      expect(SecureRandom).to receive(:uuid).and_return('SECURE_UUID')
      expect(subject.uuid).to eq 'SECURE_UUID'
    end
  end
  
  context 'random_2_digit_hex' do
    it 'create a byte long hex number' do
      expect(SecureRandom).to receive(:random_number).with(256).and_return 42
      expect(subject.random_2_digit_hex).to eq '2a'
    end
  end
  
  context 'to_param' do
    it 'should have name as param' do
      subject.name = 'blafasel'
      expect(subject.to_param).to eq 'blafasel'
    end
  end
  
  context 'item_issue_chain' do
    it 'should return chained items to guest for ItemIssue' do
      subject.host = host
      expect(subject.item_issue_chain).to eq [host, subject]
    end
  end
  
  context 'exec' do
    it 'should pass to host exec called with lxd exec' do
      subject.host = host
      allow(subject).to receive(:current_lxd_container).and_return double(name: 'some_guest-202004011337342')
      expect(host).to receive(:exec).with('/usr/bin/lxc exec some_guest-202004011337342 -- command').and_return [true, 'success']
      expect(subject.exec 'command').to eq [true, 'success']
    end
  end
 
  context 'exec!' do
    it 'should pass thru to host exec!' do
      subject.host = host
      allow(subject).to receive(:current_lxd_container).and_return double(name: 'some_guest-202004011337342')
      expect(host).to receive(:exec!).with('/usr/bin/lxc exec some_guest-202004011337342 -- command', 'error message').and_return 'success'
      expect(subject.exec! 'command', 'error message').to eq 'success'
    end
  end
  
  context 'host_root_path' do
    it 'should return path to container rootfs on host' do
      allow(subject).to receive(:current_lxd_container).and_return double(name: 'some_guest-202004011337342')
      
      expect(subject.host_root_path).to eq "/var/lib/lxd/containers/some_guest-202004011337342/rootfs/"
    end
  end
  
  context 'certificates' do
    it 'should get certificates used in guest and services' do
      guest_certificates = [BSON::ObjectId.new, BSON::ObjectId.new]
      service_certificate = BSON::ObjectId.new
      allow(subject.guest_certificates).to receive(:pluck).with(:certificate_id).and_return guest_certificates
      
      service1 = double CloudModel::Services::Ssh
      service2 = double CloudModel::Services::Nginx, ssl_cert_id: service_certificate
      allow(subject).to receive(:services).and_return [service1, service2]
      
      expect(CloudModel::Certificate).to receive(:where).with(:id.in => guest_certificates + [service_certificate]).and_return 'CERTS'
      
      expect(subject.certificates).to eq 'CERTS'
    end
  end
  
  context 'has_certificates?' do
    it 'should be true if guest has certificates' do
      allow(subject).to receive(:certificates).and_return [double]
      
      expect(subject.has_certificates?).to eq true
    end
    
    it 'should be false if guest has certificates' do
      allow(subject).to receive(:certificates).and_return []
      
      expect(subject.has_certificates?).to eq false
    end
  end
  
  context 'has_service_type?' do
    before do
      allow(subject).to receive(:services).and_return [
        double(_type: "CloudModel::Services::Mongodb"),
        double(_type: "CloudModel::Services::Nginx"),        
      ]
    end
    
    it 'should return true if services include given type' do
      expect(subject.has_service_type? "CloudModel::Services::Mongodb").to eq true
    end
  
    it 'should return true if services include given type as Class' do
      expect(subject.has_service_type? CloudModel::Services::Mongodb).to eq true
    end
  
    it 'should return false if services not include given type' do
      expect(subject.has_service_type? "CloudModel::Services::Solr").to eq false
    end
  end
  
  context 'components_needed' do
    it 'should collect all needed components from services' do
      allow(subject).to receive(:services).and_return [
        double(components_needed: [:ruby, :nginx]),
        double(components_needed: [:ruby, :mongodb]),        
      ]
      expect(subject.components_needed).to eq [:mongodb, :nginx, :ruby]
    end
  end
  
  context 'template_type' do
    it 'should find or create GuestTemplateType for needed components' do
      template_type = double CloudModel::GuestTemplateType
      allow(subject).to receive(:components_needed).and_return [:nginx, :ruby]
      expect(CloudModel::GuestTemplateType).to receive(:find_or_create_by).with(components: [:nginx, :ruby]).and_return template_type
      expect(subject.template_type).to eq template_type
    end
  end
  
  context 'template' do
    it 'should get last usable template for guest' do
      template_type = double CloudModel::GuestTemplateType
      template = double CloudModel::GuestTemplate
      host = double CloudModel::Host
    
      allow(subject).to receive(:template_type).and_return template_type
      allow(subject).to receive(:host).and_return host
      allow(template_type).to receive(:last_useable).with(host).and_return template
    
      expect(subject.template).to eq template
    end
  end
  
  context 'worker' do
    it 'should return worker for guest' do
      worker = double CloudModel::GuestWorker
      expect(CloudModel::GuestWorker).to receive(:new).with(subject).and_return worker  
      
      expect(subject.worker).to eq worker
    end
  end
  
  context '#deploy_state_id_for' do
    CloudModel::Guest.enum_fields[:deploy_state][:values].each do |k,v|
      it "should map #{v} to id #{k}" do
        expect(CloudModel::Guest.deploy_state_id_for v).to eq k
      end
    end
  end
  
  context '#deployable_deploy_states' do
    it 'should list deployable deploy_states' do
      expect(subject.class.deployable_deploy_states).to eq [:finished, :failed, :not_started]
    end
  end
  
  context '#deployable_deploy_state_ids' do
    it 'should list deployable deploy_state_ids' do
      expect(subject.class.deployable_deploy_state_ids).to eq [240, 241, 255]
    end
  end
  
  context 'deployable?' do
    it 'should be true if state is :finished' do
      subject.deploy_state = :finished
      expect(subject).to be_deployable
    end
    
    it 'should be true if state is :failed' do
      subject.deploy_state = :failed
      expect(subject).to be_deployable
    end
    
    it 'should be true if state is :not_started' do
      subject.deploy_state = :not_started
      expect(subject).to be_deployable
    end
    
    it 'should be false if state is :pending' do
      subject.deploy_state = :pending
      expect(subject).not_to be_deployable
    end
    
    it 'should be false if state is :running' do
      subject.deploy_state = :running
      expect(subject).not_to be_deployable
    end    
  end
  
  context '#deployable' do
    it 'should return all deployable Guests' do
      scoped = double
      deployable_guests = double
      allow(CloudModel::Guest).to receive(:scoped).and_return scoped
      allow(CloudModel::Guest).to receive(:deployable_deploy_state_ids).and_return [240, 241, 255]
      expect(scoped).to receive(:where).with(:deploy_state_id.in => [240, 241, 255]).and_return deployable_guests
      expect(CloudModel::Guest.deployable).to eq deployable_guests
    end
  end
  
  context 'deploy' do
    it 'should call rake cloudmodel:host:deploy with host´s and guest´s id' do
      subject.host = host
      expect(CloudModel).to receive(:call_rake).with('cloudmodel:guest:deploy', host_id: host.id, guest_id: subject.id)
      subject.deploy
    end 
    
    it 'should add an error if call_rake excepts' do
      subject.host = host
      allow(CloudModel).to receive(:call_rake).with('cloudmodel:guest:deploy', host_id: host.id, guest_id: subject.id).and_raise 'ERROR 42'
      subject.deploy
      expect(subject.deploy_state).to eq :failed
      expect(subject.deploy_last_issue).to eq 'Unable to enqueue job! Try again later.'
    end
    
    it 'should not call rake if not deployable' do
      subject.host = host
      expect(CloudModel).not_to receive(:call_rake).with('cloudmodel:guest:deploy', host_id: host.id, guest_id: subject.id)
      allow(subject).to receive(:deployable?).and_return false
      expect(subject.deploy).to eq false
    end
  end  
  
  context 'deploy!' do
    it 'should call worker to deploy Guest' do
      worker = double CloudModel::GuestWorker, deploy: true
      expect(subject).to receive(:worker).and_return worker
      allow(subject).to receive(:deployable?).and_return true
      
      expect(subject.deploy!).to eq true
    end
    
    it 'should return false and not run worker if not deployable' do
      expect(subject).not_to receive(:worker)
      allow(subject).to receive(:deployable?).and_return false
      
      expect(subject.deploy!).to eq false
      expect(subject.deploy_state).to eq :not_started
    end
    
    it 'should allow to force deploy if not deployable' do
      worker = double CloudModel::GuestWorker, deploy: true
      expect(subject).to receive(:worker).and_return worker
      allow(subject).to receive(:deployable?).and_return false
      
      expect(subject.deploy! force:true).to eq true
    end
  end
  
  context 'redeploy' do
    it 'should call rake cloudmodel:host:deploy with host´s and guest´s id' do
      subject.host = host
      expect(CloudModel).to receive(:call_rake).with('cloudmodel:guest:redeploy', host_id: host.id, guest_id: subject.id)
      subject.redeploy
    end 
    
    it 'should add an error if call_rake excepts' do
      subject.host = host
      allow(CloudModel).to receive(:call_rake).with('cloudmodel:guest:redeploy', host_id: host.id, guest_id: subject.id).and_raise 'ERROR 42'
      subject.redeploy
      expect(subject.deploy_state).to eq :failed
      expect(subject.deploy_last_issue).to eq 'Unable to enqueue job! Try again later.'
    end
    
    it 'should not call rake if not deployable' do
      subject.host = host
      expect(CloudModel).not_to receive(:call_rake).with('cloudmodel:guest:redeploy', host_id: host.id, guest_id: subject.id)
      allow(subject).to receive(:deployable?).and_return false
      expect(subject.redeploy).to eq false
    end
  end
  
  context 'redeploy!' do
    it 'should call worker to deploy Guest' do
      worker = double CloudModel::GuestWorker, redeploy: true
      expect(subject).to receive(:worker).and_return worker
      allow(subject).to receive(:deployable?).and_return true
      
      expect(subject.redeploy!).to eq true
    end
    
    it 'should return false and not run worker if not deployable' do
      expect(subject).not_to receive(:worker)
      allow(subject).to receive(:deployable?).and_return false
      
      expect(subject.redeploy!).to eq false
      expect(subject.deploy_state).to eq :not_started
    end
    
    it 'should allow to force deploy if not deployable' do
      worker = double CloudModel::GuestWorker, redeploy: true
      expect(subject).to receive(:worker).and_return worker
      allow(subject).to receive(:deployable?).and_return false
      
      expect(subject.redeploy! force:true).to eq true
    end
  end
  
  context '#redeploy' do
    before do
      allow_any_instance_of(CloudModel::Host).to receive(:exec).and_return [true, '']
    end    
    
    let!(:guest1) { Factory :guest, name: 'g1', private_address: '10.42.0.23' }
    let!(:guest2) { Factory :guest, name: 'g2', private_address: '10.42.0.25' }
    let!(:guest3) { Factory :guest, name: 'g3', private_address: '10.42.0.4' }
    
    it 'should call rake cloudmodel:host:deploy_many with list of guest ids' do  
      expect(CloudModel).to receive(:call_rake).with('cloudmodel:guest:redeploy_many', guest_ids: "#{guest1.id} #{guest3.id}")
      CloudModel::Guest.redeploy ['2600', guest1.id.to_s, guest3.id]

      expect(guest1.reload.deploy_state).to eq :pending
      expect(guest2.reload.deploy_state).to eq :not_started
      expect(guest3.reload.deploy_state).to eq :pending    
    end 
    
    it 'should add an error if call_rake excepts' do
      allow(CloudModel).to receive(:call_rake).with('cloudmodel:guest:redeploy_many', guest_ids: [guest1.id, guest3.id] * '').and_raise 'ERROR 42'
      CloudModel::Guest.redeploy ['2600', guest1.id.to_s, guest3.id]
      expect(guest1.reload.deploy_state).to eq :failed
      expect(guest1.deploy_last_issue).to eq 'Unable to enqueue job! Try again later.'
      expect(guest2.deploy_state).to eq :not_started
      expect(guest2.deploy_last_issue).to be_nil
      expect(guest3.reload.deploy_state).to eq :failed
      expect(guest3.deploy_last_issue).to eq 'Unable to enqueue job! Try again later.'
    end
    
    it 'should not call rake if not deployable' do
      expect(CloudModel).not_to receive(:call_rake).with('cloudmodel:guest:redeploy_many', guest_ids: [guest1.id, guest3.id].map(&:to_s))
      expect(CloudModel::Guest.redeploy ['2600']).to eq false
    end
  end
  
  context 'check_mk_agent' do
    pending
  end
  
  context 'system_info' do
    pending
  end
  
  context 'mem_usage' do
    pending
  end
  
  context 'cpu_usage' do
    pending
  end
   
  context 'live_lxc_info' do
    it 'should delegate to current container' do
      lxc_info = double
      allow(subject).to receive(:current_lxd_container).and_return double
      expect(subject.current_lxd_container).to receive(:live_lxc_info).and_return lxc_info
      expect(subject.live_lxc_info).to eq lxc_info
    end
    
    it 'should return nil if no current container' do
      allow(subject).to receive(:current_lxd_container).and_return nil
      expect(subject.live_lxc_info).to eq nil
    end
  end
  
  context 'lxc_info' do
    it 'should delegate to current container' do
      lxc_info = double
      allow(subject).to receive(:current_lxd_container).and_return double
      expect(subject.current_lxd_container).to receive(:lxc_info).and_return lxc_info
      expect(subject.lxc_info).to eq lxc_info
    end
    
    it 'should return nil if no current container' do
      allow(subject).to receive(:current_lxd_container).and_return nil
      expect(subject.lxc_info).to eq nil
    end
    
  end
  
  context 'start' do
    pending
  end
  
  context 'stop' do
    pending
  end
  
  context 'stop!' do
    pending
  end
  
  context 'fix_lxd_custom_volumes' do
    pending
  end
  
  context 'backup' do
    pending
  end
  
  context 'restore' do
    pending
  end
  
  context 'generate_mac_address' do
    pending
  end
  
  context 'set_dhcp_private_address' do
    pending
  end
  
  context 'set_mac_address' do
    pending
  end
end