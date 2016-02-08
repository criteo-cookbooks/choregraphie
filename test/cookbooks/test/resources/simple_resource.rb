actions :manage

default_action :manage

attribute :name, String, name_attribute: true, required: true
attribute :content, String, required: true
