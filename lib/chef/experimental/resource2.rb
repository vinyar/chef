class Chef
  module Experimental
    class Resource2 < Chef::Resource
      def current_resource
        return @current_resource if instance_variable_defined?(:@current_resource)
        provider = provider_for_action(self.class.default_action)
        provider.load_current_resource
        @current_resource = provider.current_resource
      end

      def self.property_type(type=NOT_PASSED,**options,&block)
        # Combine the type with "is"
        if type != NOT_PASSED
          if options[:is]
            options[:is] = ([ type ] + [ options[:is] ]).flatten(1)
          else
            options[:is] = type
          end
        end

        ReadProperty.new(**options)
      end

      def self.load(&block)
        new_action_provider_class.load_block = block
      end

      def self.new_action_provider_class
        return @action_provider_class if @action_provider_class

        unless self == Resource2
          base_provider = superclass.action_provider_class
        end

        base_provider ||= ActionProviderClass

        resource_class = self
        action_provider_class = Class.new(base_provider) do
          use_inline_resources
          include_resource_dsl true
        end
        action_provider_class.resource_class = self
        @action_provider_class = action_provider_class
      end

      class ActionProviderClass < Chef::Provider
        def initialize(*args)
          super
          remove_instance_variable(:@current_resource)
        end

        def load_current_resource
          # Copy over all non-desired-state
          self.current_resource = self.class.resource_class.new(new_resource.name, run_context)
          current_resource.instance_eval { @current_resource = nil }
          self.class.resource_class.state_properties.each do |property|
            if property.is_set?(new_resource)
              property.set(current_resource, property.get(new_resource))
            end
          end
          begin
            current_resource.instance_eval(&self.class.load_block)
          rescue ResourceDoesNotExistError
            self.current_resource = nil
          end
        end

        def converge(*properties, &converge_block)
          properties = new_resource.state_properties if properties.empty?
          modified = properties.map do |property|
            property = new_resource.properties[property] if !property.is_a?(Property)
            new_value = property.get(new_resource)
            if current_resource.nil?
              "  set #{property.name} to #{new_value}"
            elsif property.is_set?(new_resource)
              current_value = property.get(current_resource)
              if new_value != current_value
                "  set #{property.name} to #{new_value} (was #{current_value})"
              end
            end
          end.compact

          if !modified.empty?
            if current_resource.nil?
              converge_by([ "create #{current_resource}", **modified ], &converge_block)
            else
              converge_by([ "update #{current_resource}", **modified ], &converge_block)
            end
          end
        end

        def resource_does_not_exist!
          raise ResourceDoesNotExistError, new_resource
        end

        def self.resource_class
          @resource_class
        end
        def self.resource_class=(value)
          raise "Cannot set resource_class on #{self} to two different resources! (Setting to #{value}, was #{resource_class})" if resource_class && resource_class != value
          @resource_class = value
        end

        def self.load_block
          return @load_block if @load_block
          return superclass.load_block if superclass.respond_to?(:load_block)
        end
        def self.load_block=(value)
          @load_block = value
        end

        def self.to_s
          "#{resource_class} action provider"
        end
        def self.inspect
          to_s
        end
      end

      class ReadProperty < Property
        def get(resource)
          if !is_set?(resource) && desired_state? && resource.current_resource
            super(resource.current_resource)
          else
            super(resource)
          end
        end
      end
    end
  end

  class ResourceDoesNotExistError < StandardError
  end
end
