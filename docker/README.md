# Running TAPAS-xq with Docker

TAPAS-xq can be run in a Docker image, using the files contained in the `docker/` directory. This method is useful for reproducing the app in a working environment, without a lot of fiddly installation work.

You will need:

* some familiarity with the command line;
* [Docker](https://docs.docker.com/get-docker/); and
* [a copy of the TAPAS-xq repository](https://github.com/NEU-DSG/tapas-xq).


## Build the Docker image

First, you’ll need to [build a Docker image](https://docs.docker.com/engine/reference/builder/). Using the command line, navigate to the main directory which contains the TAPAS-xq repository, for example:

```shell
cd /Users/aclark/Documents/tapas-xq
```

Then, instruct Docker to use the `Dockerfile` in this folder to construct an image with the name "tapas-xq":

```shell
docker build --file docker/Dockerfile --tag tapas-xq . 
```

As part of this process, Docker follows the instructions given in [the Dockerfile](./Dockerfile). We start with a pre-built [Eclipse Temurin Docker container](https://hub.docker.com/_/eclipse-temurin). From there, Docker:

* installs software packages for `git`, `unzip`, and `curl`;
* installs BaseX and places a copy of the Saxon HE processor into its `lib/custom` directory;
* copies the TAPAS-xq code into the right place;
* sets up the "admin" user password ("admin");
* further configures BaseX to require basic authentication on the RESTXQ servlet; and
* runs the [installation script](../modules/installation.bxs).

Building the image will take some time, but some steps, such as downloading the BaseX and Saxon HE packages, will be cached to save time on future rebuilds.


## Start the application

Once the build process is complete, you can start up a Docker container by running this command:

```shell
docker run -p 8080:8080 --name=basex-tapas tapas-xq
```

This command tells Docker to use the "tapas-xq" image to generate and run a container named "basex-tapas". Docker will map the container's port 8080 to your computer's port 8080, letting you visit the application in the browser.

When you see lines that look like this: 

```
HTTP Server was started (port: 8080).
HTTP STOP Server was started (port: 8081).
```

...you can visit BaseX's [Database Administration page](http://localhost:8080/dba/login). Visit the TAPAS-xq README for more information on [working with BaseX and TAPAS-xq](../README.md#working-with-basex-and-tapas-xq).

To stop the Docker container, hit the <kbd>Control</kbd> and <kbd>c</kbd> keys while inside the Terminal window where the Docker container is running.

To restart the "basex-tapas" Docker container, you can run this command:

```shell
docker restart basex-tapas
```


### Inside the Docker container

It's (unfortunately) less convenient to use the command line than it is to use the Docker Desktop to explore the contents of a Docker container.

The main points of interest within the Docker container environment are:

* BaseX directory: `/opt/basex`
* BaseX configuration file: `/opt/basex/webapp/WEB-INF/web.xml`
* TAPAS-xq: `/opt/basex/webapp/tapas-xq`
* View packages: `/opt/basex/webapp/tapas-xq/view-packages`

To read or edit files inside the Docker container, use the [Docker Desktop Files editor](https://docs.docker.com/desktop/use-desktop/container/#files).


## Updating the Docker image

Once you’ve made changes to the TAPAS-xq code base, you’ll need to rebuild the "tapas-xq" Docker image so that your changes are reflected. As before, navigate to the `tapas-xq` folder on your filesystem, and run this command:

```shell
docker build --file docker/Dockerfile --tag tapas-xq .
```

To run the Docker container, you’ll first have to delete the old one, then tell Docker to start up a new container with the same name:

```shell
docker rm basex-tapas
docker run -p 8080:8080 --name=basex-tapas tapas-xq
```


## Troubleshooting

### File system space

If Docker images can’t be built because there isn’t enough space on the disk, you may be able to clear up some space by deleting old, out-of-date Docker images, containers, and other cache objects.

To see all containers and images currently stored on your computer, run:

- `docker ps -a` to list all containers and their current statuses
- `docker image ls` list all images on this computer
  - Those with `<none>` in the repository column are dangling images left over from older builds.

If you have a lot of older resources, you can use Docker’s pruning capabilities to remove them. The command below will remove all stopped containers, dangling images, and dangling build caches.

```shell
docker system prune
```

For more information on pruning, see the Docker documentation ["Prune unused Docker objects"](https://docs.docker.com/config/pruning/).
