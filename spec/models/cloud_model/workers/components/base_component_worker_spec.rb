# encoding: UTF-8

require 'spec_helper'

describe CloudModel::Workers::Components::BaseComponentWorker do
  let(:host) {double CloudModel::Host}
  subject {CloudModel::Workers::Components::BaseComponentWorker.new host}
  
  it { expect(subject).to be_a CloudModel::Workers::BaseWorker }
end