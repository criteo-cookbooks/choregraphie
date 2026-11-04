# Default Consul endpoint used by consul_lock and consul_rack_lock for their
# lock requests (e.g. 'https://consul.example.com:443'). An explicit
# `http_addr:` option on the primitive takes precedence. When nil, locks use
# the global Diplomat configuration.
default['choregraphie']['consul_lock']['http_addr'] = nil
