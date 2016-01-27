require 'chef/event_dispatch/base'
require 'chef/event_dispatch/dispatcher'
require 'chef/provider'

module ProviderMonkeyPatch

  def ProviderMonkeyPatch.included(klass)
    klass.class_eval do
      alias_method :old_converge_by, :converge_by
      def converge_by(description, &block)
        if !Chef::Config[:why_run]
          Chef::Log.debug "Calling resource_pre_converge event"
          events.resource_pre_converge(@new_resource, @action, description)
        end
        old_converge_by(description, &block)
      end
    end
  end
end

class Chef

  # add a new event called resource_pre_converge
  # This event is used for provider supporting why_run mode by using converge_by method
  module EventDispatch
    class Base
      def resource_pre_converge(resource, action, description)
      end
    end
    class Dispatcher
      def resource_pre_converge(*args)
        call_subscribers(:resource_pre_converge, *args)
      end
    end
  end

  class Provider
    # since cookbook libraries are *loaded* in each cookbook that depends on it
    include ProviderMonkeyPatch unless included_modules.include?(ProviderMonkeyPatch)
  end
end
