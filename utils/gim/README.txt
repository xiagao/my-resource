Guest ISO Manager (GIM)

    This tool is used for managing the guest ISO images which will be used in
automation testing. It provides a server tool to execute the updating task,
and a client tool to be able to trigger the task on a remote host, such as a
jenkins slave.


To setup a GIM service, please follow the steps below.

  1. Modify the configuration, for example:

    +- config.ini -+

    [gim]
    ; URL path of the server which provides compose tree of the ISO image
    top_url = http://download.eng.bos.redhat.com
    ; Path of the directory to keep your ISO images
    isos_dir = /home/isos
    ; Whether keep the old ISO images
    keep_old = no

    [httpd]
    ; Please set the value to '127.0.0.1' if just setup service on localhost
    host = 0.0.0.0
    port = 8000

  2. Run HTTP service

    $ ./gim-httpd start

  3. Test the connect

    $ curl http://<your host address>:<port number>
    {"return": 0}


To trigger an update, please run the following step.

    $ ./gim-client -H <gim server address> -p <port number> \
        -c <compose id> -A <arch list>

for example:

    $ ./gim-client -H 127.0.0.1 -p 8000 -c 'RHEL-7.2-20151030.0' \
        -A 'x86_64,ppc64,ppc64le'

The return code means:

    0 - Task finished successfully
    1 - Error occurred during task executing
