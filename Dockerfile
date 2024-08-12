FROM amazonlinux:latest AS base

#------------------------------------------------
# provided by docker
ARG TARGETOS TARGETARCH

ARG USER_HOME_DIR="/root"

#TODO to support multi-platform, multi-runtime, runtime versions etc
# can be python, go, node etc.
ARG RUNTIME="net" 
#8  or 6 (tbi) ... 39 (for python), 20 (for node) (you name it, it is a TBI anyway)
ARG RUNTIMEVER="8"
#core or web (tbi), have no idea if it applies to other runtimes 
ARG SDK="core"

#ENV TARGETPLATFORM=$TARGETPLATFORM
ENV TARGETARCH=$TARGETARCH
ENV TARGETOS=$TARGETOS
ENV USER_HOME_DIR=$USER_HOME_DIR
ENV RUNTIME=$RUNTIME
ENV RUNTIMEVER=$RUNTIMEVER
ENV SDK=$SDK
#------------------------------------------------

RUN dnf install -y tar which gzip vim findutils git wget zip unzip awscli-2 alternatives
RUN mkdir -p /opt
RUN mkdir -p /var
RUN mkdir -p /var/task

FROM base AS sdk
RUN dnf install -y "dotnet-sdk-${RUNTIMEVER}.0" gcc-c++ gcc alternatives
ENV PATH="$PATH:${USER_HOME_DIR}/.dotnet/tools"

FROM sdk AS sam
WORKDIR ${USER_HOME_DIR}
#TODO: build pakcage name based on ARGs/ENV
RUN echo "HOSTTYPE: ${HOSTTYPE}"
RUN wget https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
RUN unzip aws-sam-cli-linux-x86_64.zip -d ./sam-install
RUN ./sam-install/install
RUN rm -rf sam-install
RUN rm -f aws-sam-cli-linux*
ENV SAM_CLI_TELEMETRY=0
COPY ./.aws ${USER_HOME_DIR}/.aws 

FROM sam AS src
COPY ./src ${USER_HOME_DIR}
RUN find ${USER_HOME_DIR} -type f -name "*.sh" -exec chmod +x {} \;
#Optional to have Visual Code help while on playground
#COPY ./.vscode-server ${USER_HOME_DIR}/.vscode-server

FROM src AS createlayer
RUN ${USER_HOME_DIR}/scripts/create_layer.sh
#DBG
#RUN ls -altr /root/output

FROM scratch AS copytohost
ARG USER_HOME_DIR="/root"
COPY --link --from=createlayer /root/output /bin
#COPY --link --from=src /root/.vscode-server /.vscode-server

FROM src AS shell
COPY ./src/scripts/docker_entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker_entrypoint.sh
WORKDIR ${USER_HOME_DIR}
#ENTRYPOINT [ "/usr/local/bin/docker_entrypoint.sh" ]
CMD ["/bin/bash"]
