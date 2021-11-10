name             'choregraphie'
maintainer       'SRE-Core'
maintainer_email 'g.seux@criteo.com'
license          'Apache-2.0'
description      'Coordinates the application of changes induced by chef'
long_description 'Installs/Configures choregraphie'
issues_url       'https://github.com/criteo-cookbooks/choregraphie' if respond_to? :issues_url
source_url       'https://github.com/criteo-cookbooks/choregraphie' if respond_to? :source_url
version          '0.16.3'
supports         'centos'
supports         'windows'
chef_version     '>= 13.0.0'

depends          'resource-weight'
