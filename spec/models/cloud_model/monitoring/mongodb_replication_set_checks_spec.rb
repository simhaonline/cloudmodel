# encoding: UTF-8

require 'spec_helper'

describe CloudModel::Monitoring::MongodbReplicationSetChecks do
  let(:mongodb_replication_set) { double CloudModel::MongodbReplicationSet }
  subject { CloudModel::Monitoring::MongodbReplicationSetChecks.new mongodb_replication_set, skip_header: true }

  it { expect(subject).to be_a CloudModel::Monitoring::BaseChecks }
  
  describe 'aquire_data' do
    it 'should be nil for now' do
      expect(subject.aquire_data).to eq nil
    end
  end
  
  describe 'check' do
    it 'should be nil for now' do
      expect(subject.check).to eq nil
    end
  end
end