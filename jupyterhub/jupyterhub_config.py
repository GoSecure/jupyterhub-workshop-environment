# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

# Configuration file for JupyterHub
import os

c = get_config()
#c.JupyterHub.log_level = 'DEBUG'

# We rely on environment variables to configure JupyterHub so that we
# avoid having to rebuild the JupyterHub container every time we change a
# configuration parameter.

# Here we define a special DockerSpawner to be used when we want to expose the
# Jupyter Notebook straight to the Internet
from dockerspawner import DockerSpawner
from jupyterhub.utils import random_port
from tornado import gen

class custom_spawner(DockerSpawner):
    @gen.coroutine
    def get_ip_and_port(self):
        return self.host_ip, self.port

    @gen.coroutine
    def start(self, *args, **kwargs):
        self.port = random_port()

        # Pass the random port picked up to the container. This makes the
        # reserve-proxy work when in network exposed mode.
        spawn_cmd = "start-singleuser.sh --port={}".format(self.port)
        self.extra_create_kwargs.update({"command": spawn_cmd})

        # start the container
        ret = yield DockerSpawner.start(self, *args, **kwargs)
        return ret

if os.environ.get('DOCKER_NOTEBOOK_EXPOSE_NETWORK', False):
    # Spawn single-user servers with their network exposed as Docker containers
    c.JupyterHub.spawner_class = custom_spawner
    network_name = 'host'
    c.DockerSpawner.use_internal_ip = False

else:
    # Spawn single-user servers as Docker containers
    c.JupyterHub.spawner_class = 'dockerspawner.DockerSpawner'

    # JupyterHub requires a single-user instance of the Notebook server, so we
    # default to using the `start-singleuser.sh` script included in the
    # jupyter/docker-stacks *-notebook images as the Docker run command when
    # spawning containers.  Optionally, you can override the Docker run command
    # using the DOCKER_SPAWN_CMD environment variable.
    spawn_cmd = os.environ.get('DOCKER_SPAWN_CMD', "start-singleuser.sh")
    c.DockerSpawner.extra_create_kwargs.update({ 'command': spawn_cmd })

    # Connect containers to this Docker network
    network_name = os.environ['DOCKER_NETWORK_NAME']
    c.DockerSpawner.use_internal_ip = True


# Spawn containers from this image
c.DockerSpawner.image = os.environ['DOCKER_NOTEBOOK_IMAGE']

# Network name
c.DockerSpawner.network_name = network_name
# Pass the network name as argument to spawned containers
c.DockerSpawner.extra_host_config = { 'network_mode': network_name }
# Explicitly set notebook directory because we'll be mounting a host volume to
# it.  Most jupyter/docker-stacks *-notebook images run the Notebook server as
# user `jovyan`, and set the notebook directory to `/home/jovyan/work`.
# We follow the same convention.
notebook_dir = os.environ.get('DOCKER_NOTEBOOK_DIR') or '/home/jovyan/work'
c.DockerSpawner.notebook_dir = notebook_dir
# Mount the real user's Docker volume on the host to the notebook user's
# notebook directory in the container
c.DockerSpawner.volumes = {
    'jupyterhub-user-{username}': notebook_dir,
    '/srv/workshop/': '/home/jovyan/workshop'
}
# volume_driver is no longer a keyword argument to create_container()
# c.DockerSpawner.extra_create_kwargs.update({ 'volume_driver': 'local' })
# Remove containers once they are stopped
c.DockerSpawner.remove = True
# For debugging arguments passed to spawned containers
c.DockerSpawner.debug = True

# if Network is exposed
if os.environ.get('DOCKER_NOTEBOOK_EXPOSE_NETWORK', False):
    from jupyter_client.localinterfaces import public_ips
    c.JupyterHub.hub_ip = public_ips()[0]
    c.DockerSpawner.host_ip = os.environ['HOST_IP']
# otherwise
else:
    # User containers will access hub by container name on the Docker network
    c.JupyterHub.hub_ip = 'jupyterhub'
    c.JupyterHub.hub_port = 8080

# TLS config
c.JupyterHub.port = 443
c.JupyterHub.ssl_key = os.environ['SSL_KEY']
c.JupyterHub.ssl_cert = os.environ['SSL_CERT']

# Authenticate users with GitHub OAuth
from oauthenticator.github import GitHubOAuthenticator
c.JupyterHub.authenticator_class = GitHubOAuthenticator
c.GitHubOAuthenticator.oauth_callback_url = os.environ['OAUTH_CALLBACK_URL']

# Persist hub data on volume mounted inside container
data_dir = os.environ.get('DATA_VOLUME_CONTAINER', '/data')

c.JupyterHub.cookie_secret_file = os.path.join(data_dir,
    'jupyterhub_cookie_secret')

c.JupyterHub.db_url = 'postgresql://postgres:{password}@{host}/{db}'.format(
    host=os.environ['POSTGRES_HOST'],
    password=os.environ['POSTGRES_PASSWORD'],
    db=os.environ['POSTGRES_DB'],
)

# Whitlelist users and admins
# NOTE: an empty whitelist means everyone is allowed to create an account
c.Authenticator.whitelist = whitelist = set()
c.Authenticator.admin_users = admin = set()
c.JupyterHub.admin_access = True
pwd = os.path.dirname(__file__)

# Admin users list
try:
    with open(os.path.join(pwd, 'secrets', 'admins')) as f:
        for line in f:
            if not line:
                continue
            admin.add(line.rstrip())
except FileNotFoundError:
    pass

# Users lists (if none specified, everyone allowed)
try:
    with open(os.path.join(pwd, 'secrets', 'users')) as f:
        for line in f:
            if not line:
                continue
            parts = line.split()
            name = parts[0]
            whitelist.add(name)
            if len(parts) > 1 and parts[1] == 'admin':
                admin.add(name)
except FileNotFoundError:
    pass
