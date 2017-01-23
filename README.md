# choregraphie

choregraphie is French for choreography.

[![Build Status](https://travis-ci.org/criteo-cookbooks/choregraphie.svg?branch=master)](https://travis-ci.org/criteo-cookbooks/choregraphie)

Concepts
--------

A **protected resource** is a resource whose convergence can induce downtime on the service. For instance, `service[mydatabase]` is usually a resource to protect.

A **choregraphie** describes actions which operate on some chef events. It allows, for instance, to run an action before and after the convergence of a resource (currently: after means at the end of a sucessful run).

A **primitive** is a helper for common idioms in choregraphies. Examples: grabbing a lock, silencing the monitoring, executing a shell command.


Example
-------

    choregraphie 'my elasticsearch' do
      # protect against service and network restart
      on 'service[mydatase]'
      on 'service[network]'

      # protect against all reboot resources
      on /^reboot\[/

      on :weighted_resources # compatiblity with resource-weight cookbook

      # built-in primitive
      consul_lock(path: 'choregraphie/locks/myes', concurrency: 2)

      before do
        # roll your own code
        downtime_in_monitoring
      end
    end

Support
-------

Only chef >= 12.6 is supported (due to a dependency on :before notifications).

Usage of compat\_resource cookbook is highly discouraged as it modifies chef behavior and has silently broken :before notification in the past which are the foundation of choregraphie. Branch 'criteo' in criteo-forks organization is a safely patched version of this cookbook to avoid any chef monkeypatching.

Choregraphies can be applied only on resources that support whyrun (currently chef default resources and resource/provider style).
Custom resources (the whole resource defined in the resources/ directory) are not supported at the moment (see https://github.com/chef/chef/issues/4537 for a discussion).

Available Primitives
--------------------

See the code for up-to-date information.

Two very basic primitives:

* Before: `before { ... }` will execute code before protected resources are converged. The block will receive the converged resource as argument.
* Cleanup: `cleanup { ... }` will execute code at the end of a successful chef-client run. The cleanup block will be executed at *each* chef-client run. This code should thus be efficient and safe to run at the end of all chef-client runs (for instance cleaning a file only if it exists).


Slightly more advanced primitives:
* CheckFile: `check_file '/tmp/do_it'` will wait until the given file exists on the filesystem. This file is cleaned after.
* WaitUntil: `wait_until "ping -c 1 google.com"` will wait until the command exit with a 0 status. This primitives supports string, mixlib/shellout instance and blocks.
* ConsulLock: `consul_lock {path: '/lock/my_app', id: 'my_node', concurrency: 5}` will grab a lock from consul and release it afterwards. This primitive is based on optimistic concurrency rather than consul sessions.
* ConsulMaintenance: `consul_maintenance reason: 'My reason'` will enable
  maintenance mode on the consul agent before the choregraphie starts.


Missing Primitives
------------------

Write your own, it is easy.

How to write a primitive
------------------------

You should have a look at the example primitives such as `check_file`.

Primitives can implement two callbacks: _before_ and _cleanup_. See primitives section above for more details.
