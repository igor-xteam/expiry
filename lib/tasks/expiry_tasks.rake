Dir["tasks/**/*.rake"].each { |ext| load ext } if defined?(Rake)

namespace :expiry do
  desc 'Install expiry assets and files'
  task :update do
    FileUtils.cp_r Dir.glob(File.join(File.dirname(__FILE__), 'rails', '*')), Rails.root
  end
end
