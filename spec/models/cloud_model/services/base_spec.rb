# encoding: UTF-8

require 'spec_helper'

describe CloudModel::Services::Base do
  it { expect(subject).to have_timestamps }  
  
  it { expect(subject).to have_field(:name).of_type String }
  it { expect(subject).to have_field(:public_service).of_type(Mongoid::Boolean).with_default_value_of false }
  it { expect(subject).to have_field(:has_backups).of_type(Mongoid::Boolean).with_default_value_of false }
  
  it { expect(subject).to be_embedded_in(:guest).of_type CloudModel::Guest }
  
  context '#service_types' do
    it "should return the default service types" do
      expect(CloudModel::Services::Base.service_types).to eq({
        mongodb: CloudModel::Services::Mongodb,
        nginx: CloudModel::Services::Nginx,
        redis: CloudModel::Services::Redis,
        solr: CloudModel::Services::Solr,
        ssh: CloudModel::Services::Ssh,
        tomcat: CloudModel::Services::Tomcat,
        backup: CloudModel::Services::Backup,
        monitoring: CloudModel::Services::Monitoring
      })
    end
  end
  
  context '#find' do
    it 'should find service through guest' do
      guest = double CloudModel::Guest, services: []
      expect(CloudModel::Guest).to receive(:find_by).with("services._id" => subject.id).and_return guest
      expect(guest.services).to receive(:find).with(subject.id).and_return subject
      
      expect(CloudModel::Services::Base.find(subject.id)).to eq subject
    end
  end
  
  context 'host' do
    it 'should get guest´s host' do
      host = double CloudModel::Host
      guest = double CloudModel::Guest, host: host
      allow(subject).to receive(:guest).and_return guest
      
      expect(subject.host).to eq host
    end
  end
  
  context 'private_address' do
    it 'should get guest´s private_address' do
      guest = double CloudModel::Guest, private_address: '10.42.23.17'
      allow(subject).to receive(:guest).and_return guest
      
      expect(subject.private_address).to eq '10.42.23.17'
    end
  end
  
  context 'external_address' do
    it 'should get guest´s external_address' do
      guest = double CloudModel::Guest, external_address: '10.42.23.17'
      allow(subject).to receive(:guest).and_return guest
      subject.public_service = true
      
      expect(subject.external_address).to eq '10.42.23.17'
    end
    
    it 'should not get guest´s external_address id service not public' do
      guest = double CloudModel::Guest, external_address: '10.42.23.17'
      allow(subject).to receive(:guest).and_return guest
      subject.public_service = false
      
      expect(subject.external_address).to eq nil
    end
  end
  
  context 'item_issue_chain' do
    context 'item_issue_chain' do
      it 'should return chained items to service for ItemIssue' do
        host = double CloudModel::Host
        guest = double CloudModel::Guest, host: host
        allow(subject).to receive(:guest).and_return guest
      
        expect(subject.item_issue_chain).to eq [host, guest, subject]
      end
    end
  end
  
  context 'used_ports' do
    it 'should return array with result of call to :port of the specific class' do
      allow(subject).to receive(:port).and_return(8080)
      expect(subject.used_ports).to eq [8080]
    end
  end
  
  context 'kind' do
    it 'should always return :unknown in this abstract class' do
      expect(subject.kind).to eq :unknown
    end
  end
  
  context 'components_needed' do
    it 'should always return empty array in this abstract class' do
      expect(subject.components_needed).to eq []
    end
  end
  
  context 'service_status' do
    it 'should always return false in this abstract class' do
      expect(subject.service_status).to eq false
    end
  end
  
  context 'backupable?' do
    it 'should always return false in this abstract class' do
      expect(subject.backupable?).to eq false
    end
  end
  
  context 'has_backups=' do
    it 'should always set to false if not backupable' do
      allow(subject).to receive(:backupable?).and_return false
      subject.has_backups = true
      expect(subject.has_backups).to eq false
    end
    
    it 'should allow to set to true if backupable' do
      allow(subject).to receive(:backupable?).and_return true
      subject.has_backups = true
      expect(subject.has_backups).to eq true
    end
    
    it 'should allow to set to false if backupable' do
      allow(subject).to receive(:backupable?).and_return true
      subject.has_backups = false
      expect(subject.has_backups).to eq false
    end
  end
  
  context 'backup_directory' do
    it 'should return path to backups on backup system' do
      host = double CloudModel::Host, id: BSON::ObjectId.new
      guest = double CloudModel::Guest, id: BSON::ObjectId.new, host: host
      allow(subject).to receive(:guest).and_return guest
      
      allow(CloudModel.config).to receive(:backup_directory).and_return '/var/cloudmodel_backups'
      
      expect(subject.backup_directory).to eq "/var/cloudmodel_backups/#{host.id}/#{guest.id}/services/#{subject.id}"
    end
    
  end
  
  context 'backup' do
    it 'should raise exception in not backupable class' do
      expect{ subject.backup }.to raise_error(RuntimeError, 'Service has no backups')
    end
  end
  
  context 'restore' do
    it 'should raise exception in not backupable class' do
      expect{ subject.restore }.to raise_error(RuntimeError, 'Service has no restore')
    end
  end
end