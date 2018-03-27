# choregraphie

choregraphie is French for choreography. By providing primitives to allow you to easily coordinate the convergence of Chef resources, choregraphie enables you to orchestrate the execution of actions that could cause downtime in clustered applications, among other things. For example, say you want to upgrade your Mesos cluster to the latest version but don't want to take the whole cluster offline. You could use an external orchestrator, but choregraphie means you can reduce the number of moving parts and keep all your logic and code in Chef.

By protecting your important resources with choregraphie, you can isolate risk to a single place, enabling much more controlled application of potentially dangerous changes.

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

Three very basic primitives:

* Before: `before { ... }` will execute code before protected resources are converged. The block will receive the converged resource as argument.
* Cleanup: `cleanup { ... }` will execute code at the end of a successful chef-client run. The cleanup block will be executed at *each* chef-client run. This code should thus be efficient and safe to run at the end of all chef-client runs (for instance cleaning a file only if it exists).
* Finish: `finish { ... }` will execute code after cleanup stage. There can be only one finish block.


Slightly more advanced primitives:
* CheckFile: `check_file '/tmp/do_it'` will wait until the given file exists on the filesystem. This file is cleaned after.
* WaitUntil: `wait_until "ping -c 1 google.com"` will wait until the command exit with a 0 status. This primitives supports string, mixlib/shellout instance and blocks. One can specify to run the wait_until in "before" or "cleanup" stages using the options (see code for details).
* ConsulLock: `consul_lock {path: '/lock/my_app', id: 'my_node', concurrency: 5}` will grab a lock from consul and release it afterwards. This primitive is based on optimistic concurrency rather than consul sessions. It uses `finish` block to release the lock ensuring that the lock release happens after all cleanup blocks. It is also possible to specify the `:datacenter` option to take the lock in another datacenter.
* ConsulRackLock: `consul_rack_lock {path: '/lock/my_app', id: 'my_node', rack: 'my_rack_id', concurrency: 2}` will grab a lock from consul and release it afterwards. This has the same properties as ConsulLock but will allow in node to enter if another node with the same rack is already under the lock. Concurrency level is on the number of concurrent racks (not on concurrent nodes per rack).
* ConsulMaintenance: `consul_maintenance reason: 'My reason'` will enable maintenance mode on the consul agent before the choregraphie starts.
  `consul_maintenance service_id: 'consul service_id', reason: 'My reason'` will enable maintenance mode on the consul service before the choregraphie starts.
* ConsulHealthCheck: `consul_health_check(checkids: %w(service:consul-http-agent service:myhealthcheck))` will block until consul health check is passing. By default it will wait for 150s before failing the chef run. ids for checkids are the composition of the check type  and the id of the check (For ex. for service check myhealthcheck, id is service:myhealthcheck`).
* EnsureChoregraphie: `ensure_choregraphie` will make sure that another
  choregraphie is already protecting the resources, or wait for a file (an
  optional file path can be provided). This primitive is useful for cookbook
  providers to make sure users will protect some critical
  resources.

Note: all primitives interacting with consul require the diplomat gem. You can install it easily with consul cookbook.


Missing Primitives
------------------

Write your own, it is easy.

How to write a primitive
------------------------

You should have a look at the example primitives such as `check_file`.

Primitives can implement two callbacks: _before_ and _cleanup_. See the Primitives section above for more details.
