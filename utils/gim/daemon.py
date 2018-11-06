import os
import sys
import atexit
import time
from signal import SIGTERM


class Daemon(object):

    def __init__(self, pidfile):
        self.pidfile = pidfile

    def daemonize(self):
        try:
            pid = os.fork()
            if pid > 0:
                sys.exit(0)
        except OSError as e:
            sys.stderr.write(str(e))
            sys.exit(1)

        os.setsid()
        os.umask(0o022)
        os.chdir('/')

        try:
            pid = os.fork()
            if pid > 0:
                sys.exit(0)
        except OSError as e:
            sys.stderr.write(str(e))
            sys.exit(1)

        sys.stdout.flush()
        sys.stderr.flush()
        stdin = open('/dev/null', 'r')
        stdout = open('/dev/null', 'a+')
        stderr = open('/dev/null', 'a+', 0)
        os.dup2(stdin.fileno(), sys.stdin.fileno())
        os.dup2(stdout.fileno(), sys.stdout.fileno())
        os.dup2(stderr.fileno(), sys.stderr.fileno())

        atexit.register(self.del_pidfile)
        pid = str(os.getpid())
        with open(self.pidfile, 'w+') as pidfile:
            pidfile.write(pid)

    def del_pidfile(self):
        os.remove(self.pidfile)

    def start(self):
        try:
            with open(self.pidfile, 'r') as pidfile:
                pid = pidfile.read()
        except IOError:
            pid = None

        if pid:
            sys.stderr.write('Service is running\n')
            sys.exit(1)

        self.daemonize()
        self.run()

    def stop(self):
        try:
            with open(self.pidfile, 'r') as pidfile:
                pid = pidfile.read()
        except IOError:
            pid = None

        if not pid:
            sys.stderr.write('Service is not running\n')
            return

        try:
            while True:
                os.kill(int(pid), SIGTERM)
                time.sleep(0.1)
        except OSError as e:
            if str(e).find('No such process') > 0:
                if os.path.exists(self.pidfile):
                    os.remove(self.pidfile)
                else:
                    sys.stderr.write(str(e))
                    sys.exit(1)
            pass

    def restart(self):
        self.stop()
        self.start()

    def run(self):
        pass
