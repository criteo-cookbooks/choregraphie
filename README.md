# choregraphie

choregraphie is French for choreography.

[![Build Status](https://travis-ci.org/criteo-cookbooks/choregraphie.svg?branch=master)](https://travis-ci.org/criteo-cookbooks/choregraphie)

Concepts
--------

A **choregraphie** describes actions which operate on some chef events. It allows, for instance, to run an action before and after the convergence of a resource.

A **primitive** is a helper for common idioms in choregraphies. Examples: grabbing a lock, silencing the monitoring, executing a shell command.

Support
-------

Only chef >= 12.6 is supported (due to a dependency on :before notifications).

Choregraphies can be applied only on resources that support whyrun (currently chef default resources and resource/provider style).
Custom resources (the whole resource defined in the resources/ directory) are not supported at the moment.
