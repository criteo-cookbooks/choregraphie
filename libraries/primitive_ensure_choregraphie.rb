require_relative 'primitive'

module Choregraphie
  class EnsureChoregraphie < Primitive
    def initialize(file_path = ::File.join(::Chef::Config['file_cache_path'], 'unlock_choregraphie'), options = {})
      @file_path = file_path
      @period    = options[:period] || 5
    end


    def register(choregraphie)
      current_name = choregraphie.name
      choregraphie.before do |resource_name|
        raise 'ensure_choregraphie primitive cannot be used on other events than resource convergence!' unless resource_name

        considered_choregraphies = ::Choregraphie::Choregraphie.all.reject { |c| c.name == current_name }
        if considered_choregraphies.none? { |c| c.resources.include?(resource_name) }
          Chef::Log.warn "Resource #{resource_name} is about to converge but no choregraphie has been set up to protect this, please touch file #{@file_path} if you want to converge anyway."
          sleep(@period) until ::File.exists?(@file_path)
        end
      end

      choregraphie.cleanup do
        ::FileUtils.rm(@file_path) if File.exists?(@file_path)
      end

    end
  end
end
