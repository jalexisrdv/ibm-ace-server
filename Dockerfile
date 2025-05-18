# Build and run:
#
# docker build -t ace:tag -f Dockerfile .
# docker run -e LICENSE=accept -p 7600:7600 -p 7800:7800 --rm -ti ace:tag
#
# Can also mount a volume for the work directory:
#
# docker run -e LICENSE=accept -v /what/ever/dir:/home/aceuser/ace-server -p 7600:7600 -p 7800:7800 --rm -ti ace:tag
#
# This might require a local directory with the right permissions, or changing the userid further down . . .

ARG ACE_INSTALLER_NAME=12.0.12.13-ACE-LINUX64-DEVELOPER.tar.gz
ARG ACE_VERSION=12.0.12.13

FROM registry.access.redhat.com/ubi9/ubi-minimal as builder

ARG ACE_INSTALLER_NAME
ARG ACE_VERSION

RUN microdnf update -y && microdnf install -y util-linux tar && microdnf clean all

RUN mkdir -p /opt/ibm/ace/${ACE_VERSION}

COPY ./excludes.txt /tmp/

COPY ./${ACE_INSTALLER_NAME} /opt/ibm/ace/${ACE_VERSION}

RUN tar -xzvf /opt/ibm/ace/${ACE_VERSION}/${ACE_INSTALLER_NAME} \
        --strip-components 1 \
        --exclude-from=/tmp/excludes.txt \
        --directory /opt/ibm/ace/${ACE_VERSION}

FROM registry.access.redhat.com/ubi9/ubi-minimal

ARG ACE_INSTALLER_NAME
ARG ACE_VERSION

# Force reinstall tzdata package to get zoneinfo files
RUN microdnf update -y && microdnf install -y findutils util-linux which tar && microdnf reinstall -y tzdata && microdnf clean all

# Install ACE and accept the license
COPY --from=builder /opt/ibm/ace/${ACE_VERSION} /opt/ibm/ace/${ACE_VERSION}
RUN /opt/ibm/ace/${ACE_VERSION}/ace make registry global accept license deferred \
    && useradd --uid 1001 --create-home --home-dir /home/aceuser --shell /bin/bash -G mqbrkrs aceuser \
    && su - aceuser -c "export LICENSE=accept && . /opt/ibm/ace/$ACE_VERSION/server/bin/mqsiprofile && mqsicreateworkdir /home/aceuser/ace-server" \
    && echo ". /opt/ibm/ace/$ACE_VERSION/server/bin/mqsiprofile" >> /home/aceuser/.bashrc

# Add required license as text file in Liceses directory (GPL, MIT, APACHE, Partner End User Agreement, etc)
COPY /licenses/ /licenses/

# aceuser
USER 1001

# Expose ports.  7600, 7800, 7843 for ACE;
EXPOSE 7600 7800 7843

ENV LICENSE accept

ENV ACE_VERSION=${ACE_VERSION}

# Set default Integration Server name
ENV ACE_SERVER_NAME ace-server

# Set entrypoint to run the server
ENTRYPOINT ["bash", "-c", ". /opt/ibm/ace/${ACE_VERSION}/server/bin/mqsiprofile && IntegrationServer --name ${ACE_SERVER_NAME} -w /home/aceuser/ace-server"]
