KVMQE-CI USER GUIDE
###################

.. contents::


Getting Started
===============

Welcome to be a contributor of kvmqe-ci! Please go through the following
sections to learn about the jenkins tool and setup your development
environment.


Jenkins
-------

    `Jenkins <https://jenkins.io/>`_ is an automation engine with an
    unparalleled plugin ecosystem to support all of your favorite tools in
    your delivery pipelines, whether your goal is continuous integration,
    automated testing, or continuous delivery.


Please read `this doc <https://wiki.jenkins-ci.org/display/JENKINS/Use+Jenkins>`__
to familiar with it.


.. _redhat-ci-plugin:

Jenkins RedHat-CI-Plugin
------------------------

The CI team created a `jenkins plugin <https://mojo.redhat.com/docs/DOC-986839>`_
providing several functionalities that integrated with redhat internal
services.

Please read `this doc <https://ci-ops-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/job/ci-ops-central-documentation/lastSuccessfulBuild/artifact/ci-ops-central/docs/build/html/ci-trigger.html>`__
to get the usage.


Jenkins Job Builder
-------------------

*Jenkins Job Builder (JJB)* is a tool to make you manage your jenkins jobs
easily. Install it by the following steps, and read `this manual <http://docs.openstack.org/infra/jenkins-job-builder/>`__
to get the usage.

1. Install jenkins-job-builder.

.. code:: bash

    $ pip install --user jenkins-job-builder


2. Install redhat internal extension.

.. code:: bash

    $ pip install --user --index-url=http://ci-ops-jenkins-update-site.rhev-ci-vms.eng.rdu2.redhat.com/pypi/simple jenkins-ci-sidekick


.. note::

    If using pip version 7.0.0 or later, you will need to add
    ":code:`--trusted-host ci-ops-jenkins-update-site.rhev-ci-vms.eng.rdu2.redhat.com`"
    to the command.


3. Create configuration file for *platform jenkins master*.

.. code:: bash

    $ mkdir -p ~/.config/jenkins_jobs
    $ cat > ~/.config/jenkins_jobs/jenkins_jobs.ini << EOF
    [job_builder]
    ignore_cache=True

    [jenkins]
    user=$YOUR_KERBEROS_ID
    password=$YOUR_KERBEROS_PASSWORD
    url=https://platform-stg-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/
    EOF


KVMQE-CI
--------

The *kvmqe-ci* git repository is used for keeping job definitions and it is
the main source code repository for the CI development of the kvmqe team.

To clone this repository:

.. code:: bash

    $ git clone ssh://$YOUR_KERBEROS_ID@code.engineering.redhat.com:22/kvmqe-ci


.. note::

    If you are the first time to use the `gerrit <https://code.engineering.redhat.com/>`_
    service, please upload your ``SSH Public Key`` by following
    `this guide <https://docs.engineering.redhat.com/display/HTD/Gerrit+User+Guide#GerritUserGuide-Gerritlogin>`__
    so that you can clone the above repository successfully.


----

CI Resources
============

.. _kvmqe-ci:

KVMQE-CI
--------

Sometimes, we will put some scripts or utilities into the *kvmqe-ci*
repository and reference them in CI jobs. To use this repository as a
CI resource, please clone it with ``HTTP`` (read-only access):
::

    http://git.app.eng.bos.redhat.com/git/kvmqe-ci.git


Platform Jenkins Master
-----------------------

`Platform Jenkins Master (PJM) <http://platform-stg-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/>`_
is the central jenkins master of the whole platform team. The formal product
testing workflows can be deployed on it. It do not allow to execute jobs on
this master directly so have to register your own jenkins slave to it and
restrict the jobs to be executed on your slave.

Use kerberos credential to login.


CI Red Hat Openstack
--------------------

`CI Red Hat Openstack (CI-RHOS) <https://ci-rhos.centralci.eng.rdu2.redhat.com/>`_
provides an service that can be used for assisting the CI jobs. You can create
virtual machines on this platform and use them as jenkins slave or as some
infrastructure for your jobs.

Please contact the administrator (|ci-rhos-admin|) to help create and manage
the virtual machines.

If you want to manage this platform, please get approval from administrator
first, and then you can get password of the public user "kvmqe-jenkins" from
the administrator.


.. |ci-rhos-admin| replace::

    Ping Li <pingl@redhat.com>


Beaker
------

For jobs which use `Beaker <https://beaker.engineering.redhat.com/>`_ to
execute automations, there is a generic user account so that it can help
submit the given beaker jobs.
::

    jenkins/kvmqe-jenkins.rhev-ci-vms.eng.rdu2.redhat.com@REDHAT.COM


Follow `this doc <https://mojo.redhat.com/docs/DOC-982058>`__ to configure
your host (jenkins slave) to use the above account. The ``KEYTAB`` file could
be found in the `kvmqe-ci`_ repository.


JIRA
----

If the job have interactions with `JIRA <https://projects.engineering.redhat.com/>`_,
there is a generic user account to help accomplish that.
::

    jenkins/kvmqe-jenkins.rhev-ci-vms.eng.rdu2.redhat.com


Contact |jira-account-owner| to get password.

Reference: `Python JIRA documentation <https://jira.readthedocs.io/>`_


.. attention::

    **DO NOT** public the password in your code, put it into configuration
    file.


.. |jira-account-owner| replace::

    Xu Han <xuhan@redhat.com>


Polarion
--------

At present, there are two ways to export the automation test results into the
`Polarion <https://polarion.engineering.redhat.com/polarion/>`_ tool, one is
using the functionality provided by `redhat-ci-plugin`_, and the other is to
write python script with module *Pylarion*.

Contact |pylarion-cfg-owner| to get the pylarion configuration file.

Reference: `Pylarion documentation <http://pylarion-doc.rhev-ci-vms.eng.rdu2.redhat.com/>`_


.. |pylarion-cfg-owner| replace::

   Huiqing Ding <huding@redhat.com>


----

How To
======

Deploy Jobs
-----------

To deploy jobs to jenkins master via JJB, please execute the ``update``
command with passing the job definition (file or folder), for example:

.. code:: bash

   $ jenkins-jobs --conf ~/.jenkins_jobs_pjm.ini update jobs/acceptance/


Register Jenkins Slave
----------------------

0. Prepare a host (bare metal or virtual machine) to be used as the slave
   and make sure it has the *java runtime environment* (simply, you can
   install the rpm package ``java-1.x.0-openjdk`` where ``x`` >= 7).

1. Open the jenkins site in your web browser. At the left panel, find and
   click "*Build Executor Status*".

2. Click "*New Node*", fill the "*Node Name*" and choose "*Dumb Slave*"
   (or "*Permanent Agent*" for recent version) then click "*OK*".

3. Fill the rest blanks and click "*Save*".


Restrict Where Job Can Be Run
-----------------------------

In job definition, set the ``node`` parameter with a label expression. The
value can be a single label, a node name or a more complex expressions,
for example:

.. code:: yaml

    - job-template:
        name: '{component}-{osversion}-{hardware}-runtest'
        node: 'virt-kvm-01'
        ...
