# choregraphie

choregraphie is French for choreography.

[![Build Status](https://travis-ci.org/criteo-cookbooks/choregraphie.svg?branch=master)](https://travis-ci.org/criteo-cookbooks/choregraphie)

Concepts
--------

A **choregraphie** describes actions which operate on some chef events. It allows, for instance, to run an action before and after the convergence of a resource (currently: after means at the end of a sucessful run).

A **primitive** is a helper for common idioms in choregraphies. Examples: grabbing a lock, silencing the monitoring, executing a shell command.

Support
-------

Only chef >= 12.6 is supported (due to a dependency on :before notifications).

Choregraphies can be applied only on resources that support whyrun (currently chef default resources and resource/provider style).
Custom resources (the whole resource defined in the resources/ directory) are not supported at the moment.

Available Primitives
--------------------

See the code for up-to-date information.

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

Primitives can implement two callbacks:
- _before_ is the callback called before the start of choregraphie (usually before the convergence of a resource)
- _cleanup_ is the callback called at the end of successful chef-client run. Cleanup is always called so primitives must be efficient and safe to run at the end of all chef-client runs (for instance cleaning a file only if exists).
