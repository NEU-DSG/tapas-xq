# Start from the AdoptOpenJDK image (v16), Ubuntu platform
FROM adoptopenjdk/openjdk16:jre

# Install additional dependencies with the Ubuntu package manager
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y wget unzip git curl

# Set up the cache directory for zipped resources
WORKDIR /var/cache
RUN mkdir basex
RUN mkdir saxonhe
WORKDIR /var/cache/basex

# Download BaseX
RUN --mount=type=cache,target=/var/cache/basex \
    wget https://files.basex.org/releases/11.1/BaseX111.zip

# Unpack BaseX
RUN --mount=type=cache,target=/var/cache/basex \
    unzip BaseX111.zip -d /opt

# Download the Saxon HE processor
WORKDIR /var/cache/saxonhe
RUN --mount=type=cache,target=/var/cache/saxonhe \
    wget https://github.com/Saxonica/Saxon-HE/releases/download/SaxonHE12-4/SaxonHE12-4J.zip

# Unpack Saxon HE where BaseX will find it
RUN --mount=type=cache,target=/var/cache/saxonhe \
    unzip SaxonHE12-4J.zip -d /opt/basex/lib/custom

# Copy the TAPAS-xq code into the container
COPY ./ /opt/basex/webapp/tapas-xq

# Create the BaseX admin user account password
RUN /opt/basex/bin/basexhttp -c"PASSWORD admin" -S
# RUN /opt/basex/bin/basexhttp stop

# Re-configure BaseX, requiring authentication for the RESTXQ endpoint
WORKDIR /opt/basex/webapp/WEB-INF
RUN cp web.xml web.xml.orig
RUN java -jar /opt/basex/lib/custom/saxon-he-12.4.jar \
      -s:web.xml.orig \
      -xsl:/opt/basex/webapp/tapas-xq/docker/configure-webapp.xsl \
      -o:web.xml

# Run the TAPAS-xq installation script
WORKDIR /opt/basex
RUN bin/basex webapp/tapas-xq/modules/installation.bxs

# When the Docker container starts up, run BaseX
CMD /opt/basex/bin/basexhttp -h8080
