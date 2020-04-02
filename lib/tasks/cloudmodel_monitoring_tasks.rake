namespace :cloudmodel do
  namespace :monitoring do
    desc "Check monitoring"
    task :check => [:environment] do
      CloudModel::Host.scoped.each do |host|
        CloudModel::Monitoring::HostChecks.new(host).check
        host.guests.each do |guest|
          CloudModel::Monitoring::GuestChecks.new(host, guest).check
          guest.lxd_custom_volumes.each do |lxd_custom_volume|
            CloudModel::Monitoring::LxdCustomVolumeChecks.new(host, guest, lxd_custom_volume).check
          end
          guest.services.each do |service|
            CloudModel::Monitoring::ServiceChecks.new(host, guest, service).check
          end
        end
      end
      puts "Done."
    end
  end
end