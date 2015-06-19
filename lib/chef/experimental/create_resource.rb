require 'chef/resource'
require 'chef/resource_resolver'

class Chef
  module Experimental
    module CreateResource
      # Chef.resource
      refine (class<<Chef;self;end) do
        #
        # Create a resource type.
        #
        # @param name [Symbol] The name of the resource, e.g. :my_resource
        #
        # @example
        #   Chef.resource :httpd do
        #     property :config_path, default: '/etc/httpd.conf'
        #     property :port, Integer
        #
        #     converge do
        #       package 'apache2' do
        #       end
        #       file config_path do
        #         content "port #{port}"
        #       end
        #       service 'httpd' do
        #       end
        #     end
        #   end
        #
        def resource(name, *properties, &definition)
          resource_class = Chef::ResourceResolver.resolve(name, canonical: true)
          resource_class ||= Class.new(Chef::Resource) do
            resource_name
          end

          properties.each do |property|
            case property
            when Hash
              property.each do |name, type|
                resource_class.property(name, type)
              end
            when Symbol, String
              resource_class.property(name)
            end
          end

          if definition
            resource.class_eval(&definition)
          end
        end
      end
    end
  end
end
